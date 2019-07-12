///
// Created by Руслан Давлетшин on 30/04/2018.
//

import Utils
import Foundation



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

    var processed = [Bool]()


    init(scenarios: [[String]]) {
        nodes.insert(root)
        for sc in scenarios {
            addScenario(scenario: sc)
        }

        for node in nodes {
            processed += [false]
        }
        processed += [false]

        mergeTails()

        Logger.default().info("Done merging tails")
        Logger.default().info("number of nodes before recursive merge = \(nodes.count)")
        Logger.default().info("tail = \(tail.id), has \(tail.nodesReversed.count) reverse nodes")

        let fileNameTails = "graph-tails.gv"
        let urlTails = URL(fileURLWithPath: ".").appendingPathComponent(fileNameTails)
        let myTextTails = self.dot
        let dataTails = Data(myTextTails.utf8)
        do {
            try dataTails.write(to: urlTails, options: .atomic)
        } catch {
            print(error)
        }


        for node in nodes {
            if node.id == 1 {
                if !node.nodesReversed.isEmpty {
                    Logger.default().info("Node 1 has reversed nodes...")
                } else {
                    Logger.default().info("Node 1 has no reversed nodes")

                }
                
            }
        }

//        recursiveMerge(tail)

        Logger.default().info("Done merging nodes")

        nodes.insert(tail)

        inputsSet.append(contentsOf: ScenarioTree2.buildInputsSet(forNodes: Array(nodes)))

        let fileName = "graph.gv"
        let url = URL(fileURLWithPath: ".").appendingPathComponent(fileName)
        let myText = self.dot
        let data = Data(myText.utf8)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print(error)
        }
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
            // if a node is a leaf
            if node.nodes.isEmpty {
                //look at all its parents (should be exactly one)
                if node.nodesReversed.count > 1 {
                    Logger.default().info("Assertion violated in mergeTails")
                }
                for (branch, rNodes) in node.nodesReversed {
                    //create a new branch leading to the single tail node
                    for rNode in rNodes {
                        rNode.addNode(branch: branch, node: tail)
                    }
                }

                nodesToRemove.insert(node)
            }
        }

        for node in nodesToRemove {
            Logger.default().info("Removing node \(node.id)")
            nodes.remove(node)
        }
    }

    private func recursiveMerge(_ node: ScenarioNode2) {
        if node.id == 1  {
            if node.nodesReversed.isEmpty {
                Logger.default().info("Node 1 has no reverse nodes")
                let fileName = "graph-before.gv"
                let url = URL(fileURLWithPath: ".").appendingPathComponent(fileName)
                let myText = self.dot
                let data = Data(myText.utf8)
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    print(error)
                }

            }
            for (_, rNodes) in node.nodesReversed {
                for rNode in rNodes {
                     Logger.default().info("reverse node of node 1 is node \(rNode.id)")
                }
            }
        }

//        Logger.default().info("current size=\(nodes.count), merging node \(node.id), it has children \(node.nodesReversed.count)")
        for (_, rNodes) in node.nodesReversed {
            let to = rNodes.first!
            Logger.default().info("node = \(node.id), to = \(to.id)")
            for rNode in rNodes.dropFirst() {
                Logger.default().info("node = \(node.id), to = \(to.id), rNode = \(rNode.id)")
                for (branch, nds) in rNode.nodesReversed {
                    for nd in nds {
                        nd.addNode(branch: branch, node: to)
                    }
                }
                Logger.default().info("Removing node \(rNode.id)")
                if rNode.id != 1 {
                    nodes.remove(rNode)
                }

                let fileName = "graph-after-\(rNode.id).gv"
                let url = URL(fileURLWithPath: ".").appendingPathComponent(fileName)
                let myText = self.dot
                let data = Data(myText.utf8)
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    print(error)
                }


            }

            recursiveMerge(to)
        }

//        Logger.default().info("Done merging node \(node.id)")
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
