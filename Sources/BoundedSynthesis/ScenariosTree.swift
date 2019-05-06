//
// Created by Руслан Давлетшин on 30/04/2018.
//


typealias Vars = [String]

extension Array where Element == String {
    var hashValue: Int {
        return map { $0.hashValue }.reduce(0, ^)
    }
}

struct VarsHashable {
    let vars: Vars
}

extension VarsHashable: Hashable {
    var hashValue: Int {
        return vars.hashValue
    }

    static func ==(lhs: VarsHashable, rhs: VarsHashable) -> Bool {
        return lhs.vars == rhs.vars
    }
}


struct ScenarioBranch {
    let inputs: Vars
    let outs: Vars

    let hash: Int

    init (inputs i: Vars, outs o: Vars) {
        self.inputs = i
        self.outs = o
        self.hash = (i + o).hashValue
    }
}

extension ScenarioBranch: Hashable {
    var hashValue: Int {
        return hash
    }

    static func ==(lhs: ScenarioBranch, rhs: ScenarioBranch) -> Bool {
        return lhs.inputs == rhs.inputs && lhs.outs == rhs.outs
    }
}


fileprivate func getOuts(forIO io: String) -> Vars {
    guard let outs: [String] = io.split(around: ";").1?.components(separatedBy: ",") else {
        return []
    }
    return outs[0].isEmpty ? [] : outs
}

fileprivate func getInputs(forIO io: String) -> Vars {
    let inputs: [String] = io.split(around: ";").0.components(separatedBy: ",")
    return inputs[0].isEmpty ? [] : inputs
}




class ScenarioNode2 {
    private static var id = 0
    private static func getNewId() -> Int {
        id += 1
        return id
    }

    let id: Int
    var nodes: [ScenarioBranch: ScenarioNode2]

    var nodesReversed: [ScenarioBranch: [ScenarioNode2]]

    init() {
        id = ScenarioNode2.getNewId()
        nodes = [:]
        nodesReversed = [:]
    }

    func addNode(branch b: ScenarioBranch, node n: ScenarioNode2) {
        nodes[b] = n

        if n.nodesReversed[b] == nil {
            n.nodesReversed[b] = [self]
        } else {
            n.nodesReversed[b]!.append(self)
        }
    }

    public var outs: [(Int, ScenarioBranch)] {
        return nodes.map { ($1.id, $0) }
    }
}

extension ScenarioNode2: Hashable {
    var hashValue: Int {
        return id
    }

    static func ==(lhs: ScenarioNode2, rhs: ScenarioNode2) -> Bool {
        return lhs.id == rhs.id
    }
}


class ScenarioTree2 {

    let root = ScenarioNode2()
    let tail = ScenarioNode2()
    var nodes = Set<ScenarioNode2>()

    var inputsSet: [(Vars, [Int: [(Int, ScenarioBranch)]])] = []

    var nodeIds: [Int] {
        return nodes.map { $0.id }
    }

    init(scenarios: [[String]]) {
        nodes.insert(root)
        for sc in scenarios {
            addScenario(scenario: sc)
        }

        mergeTails()

        recursiveMerge(tail)
        nodes.insert(tail)

        inputsSet.append(contentsOf: ScenarioTree2.buildInputsSet(forNodes: Array(nodes)))
    }

    func addScenario(scenario: [String]) {
        var node = root

        for i in scenario.indices {
            let item: String = scenario[i]
            let branch = ScenarioBranch(inputs: getInputs(forIO: item), outs: getOuts(forIO: item))

            if let next = node.nodes[branch] {
                node = next
            } else {
                let next = ScenarioNode2()
                nodes.insert(next)
                node.addNode(branch: branch, node: next)
                node = next
            }
        }
    }

    private func mergeTails() {
        var nodesToRemove = Set<ScenarioNode2>()
        for node in nodes {
            if node.nodes.isEmpty {
                for (branch, rNodes) in node.nodesReversed {
                    for rNode in rNodes {
                        rNode.addNode(branch: branch, node: tail)
                    }
                }
                nodesToRemove.insert(node)
            }
        }

        for node in nodesToRemove {
            nodes.remove(node)
        }
    }

    private func recursiveMerge(_ node: ScenarioNode2) {
        for (_, rNodes) in node.nodesReversed {
            let to = rNodes.first!
            for rNode in rNodes.dropFirst() {
                for (branch, nds) in rNode.nodesReversed {
                    for nd in nds {
                        nd.addNode(branch: branch, node: to)
                    }
                }
                nodes.remove(rNode)
            }

            recursiveMerge(to)
        }
    }



    private static func buildInputsSet(forNodes nodes: [ScenarioNode2]) -> [(Vars, [Int: [(Int, ScenarioBranch)]])] {
        var inputSet: [VarsHashable: [Int: [(Int, ScenarioBranch)]]] = [:]

        for node in nodes {
            for (id, branch) in node.outs {
                let inputs = VarsHashable(vars: branch.inputs)
                if !inputSet.keys.contains(inputs) {
                    inputSet[inputs] = [:]
                }

                if !(inputSet[inputs]!.keys.contains(node.id)) {
                    inputSet[inputs]?[node.id] = []
                }

                inputSet[inputs]?[node.id]?.append((id, branch))
            }
        }

        return inputSet.map { ($0.vars, $1) }
    }
}

extension ScenarioTree2 {
    public var dot: String {
        var dot: [String] = []
        for state in nodeIds {
            dot.append("\t\"s\(state)\"[shape=circle,label=\"\(state)\"];")
        }

        for node in nodes {
            for (k, v) in node.nodes {
                dot.append("\t\"s\(node.id)\" -> \"s\(v.id)\" [label=\"\(k.inputs.joined(separator: ", ")) / \(k.outs.joined(separator: ", "))\"];")
            }
        }

        return "digraph graphname {\n\(dot.joined(separator: "\n"))\n}"
    }
}
