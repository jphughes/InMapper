// The Swift Programming Language
// https://docs.swift.org/swift-book


import Foundation
import Logging
import AsyncHTTPClient

typealias IpAddr = String
extension String: Error {}
var log = Logger(label: "com.jphughes.InMapper")

extension Encodable {
	var asJSON:Data {
		get throws {
			let encoder = JSONEncoder()
			encoder.outputFormatting = .prettyPrinted
			return try encoder.encode(self)
		}
	}
}

extension Data {
	func fromJSON<T:Decodable>(to: T) throws -> T {
		let decoder = JSONDecoder()
		return try decoder.decode(T.self, from: self)
	}
}

extension Data {
	var asString: String {
		get throws {
			guard let string = String(data: self, encoding: .utf8) else {
				throw "Data not .utf8"
			}
			return string
		}
	}
}

class InMapper {
	public var nodes: [Node] { _nodes.all }
	public var edges: [Edge] { _edges.all }

	private let _nodes: Nodes
	private let _edges: Edges

	enum CodingKeys: String, CodingKey {
		case nodes
	}

	let ping = Ping()

	init() async throws {
		self._nodes = Nodes()
		self._edges = Edges()
	}

	/// Tests a node and that the next are as they say they are. '
	///
	/// Returns: true if node is where expected.
	@discardableResult
	func test(_ node: Node) async -> Node? {
		fatalError("ToDo")
	}

	/// given an IP address determine tha path from this ipAddress to
	/// the map.
	@discardableResult
	func test(_ ip: IpAddr) async throws -> Node? {
		if let node = _nodes.match(ip) {
			return await test(node)
		} else {
			return try await full(ip)
		}
	}

	private func full(_ ip:IpAddr) async throws -> Node? {
		/// we agre just getting started with this IP address. First, make sure
		/// it is actually threre otherwise the results are less interesting.
		guard case .success = await ping.send(ip, 255) else {
			return nil
		}

		var previous = _nodes.root
		for i in (1 ... 255) {
			let result = await ping.send(ip, i)
			let node = switch result {
				case .success:
					_nodes.get(ip)
				case .ttlExceeded(let ip):
					_nodes.get(ip)
				case .unknown:
					_nodes.get(previous.ip+"->next")
				case .failed(let error):
					throw "Failed \(error)"
			}
			let date = Date().timeIntervalSince1970
			let edge = _edges.get(previous.ip, node.ip)
			edge.lastSeen = date
			node.lastSeen = date
			if case .success = result { return node }
			previous = node
		}
		return nil
	}

	var newNode: (Node) async throws -> () = {_ in }
	var newEdge: (Edge) async throws -> () = {_ in }


	/// returns the node names along the path from the root to the node
	func path(_ ip:IpAddr) throws -> [Node] {

		/// get the path from this node back to the root (if there are more than one  previous,
		/// choose any one.
		guard var currentNode = _nodes.match(ip) else {
			throw "node \(ip) not found"
		}
		var pathNodes = [Node]()
		while true {
			pathNodes += [currentNode]
			let edges = _edges.match(destination: currentNode.ip)
			if edges.isEmpty { break }
			guard let nextNode = _nodes.match(edges[0].source) else {
				throw "node not found \(edges[0].source)"
			}
			currentNode = nextNode
		}

		/// reverse the list so that the index is the depth.
		return pathNodes.reversed()
	}

	var asDot: String {
		(
			[ "digraph{"] +
			nodes.map ({ """
			   "\($0.ip)";
			   """
			}) +
			edges.map({ """
			   "\($0.source)"->"\($0.destination)";
			   """
			}) + ["}"]
		).joined()
	}

}

class Edges {
	var set = Set<Edge>()

	func get(_ source: IpAddr, _ destination: IpAddr) -> Edge {
		if let edge = match(source, destination) {
			return edge
		}
		let edge = Edge(source, destination)
		set.insert(edge)
		return edge
	}

	func match (_ source:IpAddr, _ destination:IpAddr) -> Edge? {
		set.first { edge in
			(edge.source == source &&
			 edge.destination == destination)
		}
	}

	func match (source:IpAddr? = nil, destination:IpAddr? = nil) -> [Edge] {
		set.filter { edge in
			if let source = source {
				if source != edge.source { return false }
			}
			if let destination = destination {
				if destination != edge.destination {
					return false
				}
			}
			return true
		}
	}

	var all: [Edge] {
		Array(set)
	}
}


class Edge: Hashable {
	let source: String
	let destination: String
	var lastSeen: TimeInterval!

	init(_ source: String, _ destination: String) {
		self.source = source
		self.destination = destination
	}

	static func == (lhs: Edge, rhs: Edge) -> Bool {
		lhs.source == rhs.source &&
		lhs.destination == rhs.destination
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(source)
		hasher.combine(destination)
	}
}


class Nodes {

	let root: Node
	private var set: Set<Node>

	func get(_ ip:IpAddr) -> Node {
		if let node = match(ip) {
			return node
		}
		/// Node not found, create one.
		let node = Node(ip)
		set.insert(node)
		return node
	}

	init() {
		self.root = Node("root")
		self.set = []
		self.set.insert(root)
	}

	func match(_ ip: IpAddr) -> Node? {
		set.first { node in
			node.ip == ip
		}
	}

	var all: [Node] {
		Array(set)
	}

	var asDot: String {
		"ToDo"
	}

	var count:Int {
		get {
			set.count
		}
	}
}

class Node: Hashable {
	let ip: IpAddr
	let firstSeen: Double
	var lastSeen: Double

	init(_ ip: IpAddr) {
		self.ip = ip
		self.firstSeen = Date().timeIntervalSince1970
		self.lastSeen = firstSeen
	}

	static func == (lhs: Node, rhs: Node) -> Bool {
		lhs.ip == rhs.ip
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(ip)
	}
}

actor Ping {

	enum Result: Equatable {
		static func == (lhs: Ping.Result, rhs: Ping.Result) -> Bool {
			return switch (lhs, rhs) {
				case
					(.success, .success),
					(.unknown, .unknown):
					true
				case (.ttlExceeded(let x), .ttlExceeded(let y)) where x == y:
					true
				default:
					false
			}
		}

		case success, unknown, ttlExceeded(IpAddr), failed(Error)
	}

	private let client: HTTPClient
	private let host: String

	init() {
		self.client = HTTPClient()
		self.host = "James-MacStudio.1520.hughes.co:8123"
	}

	func send(_ ip:IpAddr, _ ttl: Int) async -> Result {
		do {
			precondition( (1 ... 255).contains(ttl))
			let request = HTTPClientRequest(url: "http://\(host)/ping/\(ip)/\(ttl)")
			let response = try await client.execute(request, timeout: .seconds(30))
			guard response.status == .ok else {
				return .failed("Service error, \(response.status)")
			}
			var responseBody = try await response.body.collect(upTo: 100)
			let result = responseBody
				.readString(length: responseBody.readableBytes)?
				.trimmingCharacters(in: .whitespacesAndNewlines)
			??  "No Body"
			return switch result {
				case "Success":
						.success
				case "Timeout":
						.unknown
				case let x where x.starts(with: "TTLExceeded"):
						.ttlExceeded(String(x.split(separator: " ")[1]))
				case let x:
						.failed("Unknown response: \(x)")
			}
		} catch {
			return .failed(error)
		}
	}

	deinit {
		try? client.syncShutdown()
	}
}
