import Utils
import CAiger

struct SymbolicEncoding: BoSyEncoding {
    
    let automaton: CoBüchiAutomaton
    let semantics: TransitionSystemType
    let inputs: [String]
    let outputs: [String]
    
    init(automaton: CoBüchiAutomaton, semantics: TransitionSystemType, inputs: [String], outputs: [String]) {
        self.automaton = automaton
        self.semantics = semantics
        self.inputs = inputs
        self.outputs = outputs
    }
    
    func getEncoding(forBound bound: Int) -> Logic? {
        
        let states = 0..<bound
        
        var preconditions: [Logic] = []
        var matrix: [Logic] = []
        
        let statePropositions: [Proposition] = (0..<numBitsNeeded(states.count)).map({ bit in Proposition("s\(bit)") })
        let nextStatePropositions: [Proposition] = (0..<numBitsNeeded(states.count)).map({ bit in Proposition("sp\(bit)") })
        let automatonStatePropositions: [Proposition] = automaton.states.map({ state in automatonState(state, primed: false) })
        let automatonNextStatePropositions: [Proposition] = automaton.states.map({ state in automatonState(state, primed: true) })
        let tauPropositions: [Proposition] = (0..<numBitsNeeded(states.count)).map({ bit in tau(bit: bit) })
        let inputPropositions: [Proposition] = self.inputs.map(Proposition.init)
        let outputPropositions: [Proposition] = self.outputs.map(Proposition.init)
        let tauApplications: [FunctionApplication] = tauPropositions.map({ FunctionApplication(function: $0, application: statePropositions + inputPropositions) })
        
        let numBits = numBitsNeeded(bound)
        for i in bound ..< (1 << numBits) {
            preconditions.append(!explicitToSymbolic(base: "s", value: i, bits: numBits))
            preconditions.append(!explicitToSymbolic(base: "sp", value: i, bits: numBits))
            matrix.append(!explicitToSymbolic(base: "t_", value: i, bits: numBits, parameters: statePropositions + inputPropositions))
        }
        
        // initial states
        let initialSystem = explicitToSymbolic(base: "s", value: 0, bits: numBits)
        var initialAutomaton: [Logic] = []
        for q in automaton.initialStates {
            let state: Logic = automatonState(q, primed: false)
            initialAutomaton.append(automaton.states.subtracting([q]).map({ otherQ in !automatonState(otherQ, primed: false) }).reduce(state, &))
            //initialAutomaton.append(automaton.states.map({ otherQ in !automatonState(otherQ, primed: true) }).reduce(state, &))
        }
        assert(!initialAutomaton.isEmpty)
        matrix.append((initialSystem & initialAutomaton.reduce(Literal.False, |)) --> lambda(automatonStatePropositions, states: statePropositions))
        
        
        // automaton transition function
        var deltas: [Logic] = []
        var safety: [Logic] = []
        for q in automaton.states {
            let replacer = ReplacingPropositionVisitor(replace: {
                proposition in
                if self.outputs.contains(proposition.name) {
                    let dependencies = self.semantics == .Mealy ? statePropositions + inputPropositions : statePropositions
                    return FunctionApplication(function: proposition, application: dependencies)
                } else {
                    return nil
                }
            })
            
            if let condition = automaton.safetyConditions[q] {
                safety.append(automatonState(q, primed: false) --> condition.accept(visitor: replacer))
            }
            
            // need incoming transitions
            var incoming: [Logic] = []
            for (other, outgoing) in automaton.transitions {
                for (otherPrime, guardCondition) in outgoing {
                    if otherPrime != q {
                        continue
                    }
                    if guardCondition as? Literal != nil && guardCondition as! Literal == Literal.True {
                        incoming.append(automatonState(other, primed: false))
                    } else {
                        incoming.append(automatonState(other, primed: false) & guardCondition.accept(visitor: replacer))
                    }
                }
            }
            deltas.append(automatonState(q, primed: true) <-> incoming.reduce(Literal.False, |))
        }
        let delta = deltas.reduce(Literal.True, &)
        
        // rejecting states
        let rejecting: Logic = automaton.rejectingStates.map({ state in automatonState(state, primed: true) }).reduce(Literal.False, |)
        
        matrix.append(
            (lambda(automatonStatePropositions, states: statePropositions) & delta & tauNextStateAssertion(states: nextStatePropositions, taus: tauApplications))
                -->
            (lambda(automatonNextStatePropositions, states: nextStatePropositions) &
                (rejecting --> BooleanComparator(.Less, lhs: lambdaSharp(automatonNextStatePropositions, states: nextStatePropositions), rhs: lambdaSharp(automatonStatePropositions, states: statePropositions))) &
                (!rejecting --> BooleanComparator(.LessOrEqual, lhs: lambdaSharp(automatonNextStatePropositions, states: nextStatePropositions), rhs: lambdaSharp(automatonStatePropositions, states: statePropositions)))
            )
        )
        matrix.append(lambda(automatonStatePropositions, states: statePropositions) --> safety.reduce(Literal.True, &))
        
        let formula: Logic = preconditions.reduce(Literal.True, &) --> matrix.reduce(Literal.True, &)
        
        
        let lambdaPropositions: [Proposition] = [lambdaProposition()]
        let lambdaSharpPropositions: [Proposition] = [lambdaSharpProposition()]
        
        let universalQuantified: Logic = Quantifier(.Forall, variables: statePropositions + nextStatePropositions + automatonStatePropositions + automatonNextStatePropositions + inputPropositions, scope: formula)
        let outputQuantification: Logic = Quantifier(.Exists, variables: outputPropositions, scope: universalQuantified, arity: semantics == .Mealy ? numBitsNeeded(states.count) + self.inputs.count : numBitsNeeded(states.count))
        let tauQuantification: Logic = Quantifier(.Exists, variables: tauPropositions, scope: outputQuantification, arity: numBitsNeeded(states.count) + self.inputs.count)
        let lambdaQuantification: Logic = Quantifier(.Exists, variables: lambdaPropositions + lambdaSharpPropositions, scope: tauQuantification, arity: numBitsNeeded(states.count))
        
        let boundednessCheck = BoundednessVisitor()
        assert(lambdaQuantification.accept(visitor: boundednessCheck))
        
        let removeComparable = RemoveComparableVisitor(bound: bound)
        let result = lambdaQuantification.accept(visitor: removeComparable)
        
        //print(result)
        
        return result
    }

    func explicitToSymbolic(base: String, value: Int, bits: Int, parameters: [Proposition]? = nil) -> Logic {
        var and: [Logic] = []
        for (i, bit) in binaryFrom(value, bits: bits).characters.enumerated() {
            let prop: Logic
            if let parameters = parameters {
                prop = FunctionApplication(function: Proposition("\(base)\(i)"), application: parameters)
            } else {
                prop = Proposition("\(base)\(i)")
            }
            and.append(bit == "1" ? prop : !prop)
        }
        return and.reduce(Literal.True, &)
    }
    
    func tauNextStateAssertion(states: [Proposition], taus: [FunctionApplication]) -> Logic {
        assert(states.count == taus.count)
        var assertion: [Logic] = []
        for (state, tau) in zip(states, taus) {
            assertion.append(state <-> tau)
        }
        return assertion.reduce(Literal.True, &)
    }
    
    func automatonState(_ state: String, primed: Bool) -> Proposition {
        if primed {
            return Proposition("\(state)p")
        } else {
            return Proposition("\(state)")
        }
    }
    
    func lambdaProposition() -> Proposition {
        return Proposition("l")
    }
    
    func lambda(_ automatonStates: [Proposition], states: [Proposition]) -> FunctionApplication {
        return FunctionApplication(function: lambdaProposition(), application: automatonStates + states)
    }
    
    func lambdaSharpProposition() -> Proposition {
        return Proposition("ls")
    }
    
    func lambdaSharp(_ automatonStates: [Proposition], states: [Proposition]) -> FunctionApplication {
        return FunctionApplication(function: lambdaSharpProposition(), application: automatonStates + states)
    }
    
    func tau(bit: Int) -> Proposition {
        return Proposition("t_\(bit)")
    }
    
    func output(_ name: String, forState state: Int) -> String {
        return "\(name)_\(state)"
    }
    
    mutating func solve(forBound bound: Int) throws -> Bool {
        Logger.default().info("build encoding for bound \(bound)")
        
        guard let instance = getEncoding(forBound: bound) else {
            throw BoSyEncodingError.EncodingFailed("could not build encoding")
        }
        //print(instance)
        let dqdimacsVisitor = DQDIMACSVisitor(formula: instance)
        //print(dqdimacsVisitor)
        guard let result = idq(dqdimacs: "\(dqdimacsVisitor)") else {
            throw BoSyEncodingError.SolvingFailed("solver failed on instance")
        }
        return result == .SAT
        /*let tptp3Transformer = TPTP3Visitor(formula: instance)
        print(tptp3Transformer)
        guard let result = eprover(tptp3: "\(tptp3Transformer)") else {
            throw BoSyEncodingError.SolvingFailed("solver failed on instance")
        }
        return result == .SAT*/
    }
    
    func extractSolution() -> BoSySolution? {
        return nil
    }
}