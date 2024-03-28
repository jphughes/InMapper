// The Swift Programming Language
// https://docs.swift.org/swift-book

typealias IpAddr = String

actor Nodes: Codable {
	private var dict:[String:Node] = [:]

	static var asDot: String {
		"ToDo"
	}
}

actor Node : Codable {
	let name: String
	let ip: IpAddr
	let depth: Int

	init(_ name:String, _ ip: IpAddr, _ depth:Int) {
		self.name = name
		self.ip = ip
		self.depth = depth
	}
}

actor Edges {
	private var set = Set<Edge>()

	static var asDot: String {
		"ToDo"
	}
	func add(_ edge:Edge) {
		set.insert(edge)
	}
}

actor Edge: Hashable {
	static func == (lhs: Edge, rhs: Edge) -> Bool {
		guard lhs.nodes.count == rhs.nodes.count else { return false }
		for i in (0 ..< lhs.nodes.count) {
			guard lhs.nodes[i].name == rhs.nodes[i].name else { return false }
		}
		return true
	}

	nonisolated func hash(into hasher: inout Hasher) {
		for node in nodes {
			hasher.combine(node.name)
		}
	}

	let nodes: [Node]

	init(_ nodes: Node ... ) {
		self.nodes = nodes
	}
}
