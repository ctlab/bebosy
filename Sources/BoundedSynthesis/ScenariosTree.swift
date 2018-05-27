//
// Created by Руслан Давлетшин on 30/04/2018.
//


struct ScenarioBranch {
    let inputs: [String]
    let outs: [String]

    let hash: Int

    init (inputs i: [String], outs o: [String]) {
        self.inputs = i
        self.outs = o
        self.hash = (i + o).map { $0.hashValue }.reduce(0, ^)
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



fileprivate func getOuts(forIO io: String) -> [String] {
    guard let outs: [String] = io.split(around: ";").1?.components(separatedBy: ",") else {
        return []
    }
    return outs[0].isEmpty ? [] : outs
}

fileprivate func getInputs(forIO io: String) -> [String] {
    let inputs: [String] = io.split(around: ";").0.components(separatedBy: ",")
    return inputs[0].isEmpty ? [] : inputs
}



struct ScenarioTree {
    struct ScenarioNode {
        let id: Int // just id to identify node
        var nodes: [ScenarioBranch:ScenarioNode] = [:]
    }

    var root = ScenarioNode(id: counter, nodes: [:])

    var uniqueNodes: Set<ScenarioNode> = Set()

    init(scenarios: [[String]]) {
        ScenarioTree.buildTree(&root, scenarios, &uniqueNodes)
        uniqueNodes.insert(root)
    }

    private static var counter = 0
    private static func buildTree(_ node: inout ScenarioNode, _ scenarios: [[String]], _ allNodes: inout Set<ScenarioNode>) {
        if scenarios.isEmpty { return }

        var stateMap: [ScenarioBranch: [[String]]] = [:]

        for sc in scenarios {
            if sc.isEmpty { continue }

            let branchRaw = sc.first!
            let i = getInputs(forIO: branchRaw)
            let o = getOuts(forIO: branchRaw)
            let branch = ScenarioBranch(inputs: i, outs: o)

            if !stateMap.keys.contains(branch) {
                stateMap[branch] = []
            }

            stateMap[branch]?.append(Array(sc.dropFirst()))
        }

        for (k, v) in stateMap {
            counter += 1
            var newNode = ScenarioNode(id: counter, nodes: [:])
            buildTree(&newNode, v, &allNodes)
            node.nodes[k] = newNode
            allNodes.insert(newNode)
        }
    }
}

extension ScenarioTree.ScenarioNode {
    public var size: Int {
        return nodes.count + nodes.values.map({ $0.size }).reduce(0, +)
    }

    public var dotTransitions: [String] {
        var dot: [String] = []

        for (k, v) in nodes {
            dot.append("\t\"s\(id)\" -> \"s\(v.id)\" [label=\"\(k)\"];")
            dot += v.dotTransitions
        }

        return dot
    }

    public var outs: [(Int, ScenarioBranch)] {
        return nodes.map { ($1.id, $0) }
    }

    public var nodeIds: Set<Int> {
        var ids = Set<Int>()

        for v in nodes.values {
            ids.insert(v.id)
            ids = ids.union(v.nodeIds)
        }

        return ids
    }

    public var allNodes: [ScenarioTree.ScenarioNode] {
        return nodes.map { $1 } + nodes.map { $1.allNodes } .flatMap { $0 }
    }
}

extension ScenarioTree.ScenarioNode: Hashable {
    var hashValue: Int {
        return id
    }

    static func ==(lhs: ScenarioTree.ScenarioNode, rhs: ScenarioTree.ScenarioNode) -> Bool {
        return lhs.id == rhs.id
    }
}

extension ScenarioTree {
    public var size: Int {
        return root.size + 1 // + 1 means root
    }

    public var dot: String {
        var dot: [String] = []

        for state in nodeIds {
            dot.append("\t\"s\(state)\"[shape=circle,label=\"\(state)\"];")
        }

        dot += root.dotTransitions

        return "digraph graphname {\n\(dot.joined(separator: "\n"))\n}"
    }

    public var dot2: String {
        var dot: [String] = []
        for state in nodeIds {
            dot.append("\t\"s\(state)\"[shape=circle,label=\"\(state)\"];")
        }

        for node in uniqueNodes {
            for (k, v) in node.nodes {
                dot.append("\t\"s\(node.id)\" -> \"s\(v.id)\" [label=\"\(k.inputs.joined(separator: ", ")) / \(k.outs.joined(separator: ", "))\"];")
            }
        }

        return "digraph graphname {\n\(dot.joined(separator: "\n"))\n}"
    }

    public var nodeIds: Set<Int> {
        return Set(uniqueNodes.map { $0.id })
    }

    public var nodes: [ScenarioNode] {
        return root.allNodes + [root]
    }
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