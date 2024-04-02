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

class InMapper: Codable {
	let nodes: Nodes

	enum CodingKeys: String, CodingKey {
		case nodes
	}

	let ping = Ping()

	init() async throws {
		self.nodes = try await Nodes()
	}

	/// Tests a node and that the next are as they say they are. '
	///
	/// Returns: true if node is where expected.
	@discardableResult
	func test(_ node: Node) async -> Node? {
		nil
	}

	/// given an IP address determine tha path from this ipAddress to
	/// the map.
	@discardableResult
	func test(_ ip: IpAddr) async -> Node? {
		let candidates = nodes.get(ip)
		switch candidates.count {
			case 0:
				return await full(ip)
			case 1:
				return await test(candidates[0])
			default:
				for node in candidates {
					if await test(node) != nil {
						return node
					}
				}
				return nil
		}
	}

	private func full(_ ip:IpAddr) async -> Node? {
		/// we agre just getting started with this IP address. First, make sure
		/// it is actually threre otherwise the results are less interesting.
		guard case .success = await ping.send(ip, 255) else {

			return nil
		}

		var previous = nodes.root
		for i in (1 ... 255) {
			var node:Node! = nil
			let result = await ping.send(ip, i)
			switch result {
				case .success:
					node = nodes.get(ip, i)
				case .ttlExceeded(let ip):
					node = nodes.get(ip, i)
				case .unknown:
					node = nodes.get(previous.ip+"->"+ip, i)
				case .failed(_):
					return nil
			}
			previous.next.insert(node.id)
			node.prev.insert(previous.id)
			node.lastSeen = Date().timeIntervalSince1970
			if case .success = result { return node }
			previous = node
		}
		return nil
	}
}


class Nodes: Codable {
	let root: Node
	private var nodes:[String: Node]

	/// determine the most recent node with this ip address
	func get(mostRecent ip: IpAddr) throws -> Node {
		let nodes = self.get(ip)
			.sorted{ $0.lastSeen > $1.lastSeen }
		guard nodes.count > 0 else { throw "no mode by name"}
		return nodes[0]
	}

	func get(_ ip:IpAddr) -> [Node] {
		nodes.keys.compactMap {
			if $0.split(separator: ";")[0] == ip {
				return nodes[$0]
			} else {
				return nil
			}
		}
		.sorted{ $0.depth < $1.depth }
	}

	func get(_ ip:IpAddr, _ depth:Int) -> Node {
		if ip == "unknown" {
			fatalError( "ToDo" )
		}
		if let node = nodes[Node.id(ip, depth)] {
			return node
		}
		let node = Node(ip, depth)
		nodes[node.id] = node
		return node
	}

	init() async throws {
		self.root = Node("root", 0)
		self.nodes = [root.id: root]
	}

	/// returns the node names along the path from the root to the node
	func path(_ ip:IpAddr) throws -> [Node] {

		var pathNodes: [Node] = []

		/// get the path from this node back to the root (if there are more than one  previous,
		/// choose any one.
		var currentNode = try get(mostRecent: ip)
		while currentNode.prev.count > 0 {
			pathNodes += [currentNode]
			let nextid = currentNode.prev.first!
			currentNode = nodes[nextid]!
		}

		/// reverse the list so that the index is the depth.
		return pathNodes.reversed()
	}

	var asDot: String {
		"ToDo"
	}
}

class Node : Codable {
	let ip: IpAddr
	let depth: Int
	let firstSeen: Double
	var lastSeen: Double
	var next: Set<String> = []
	var prev: Set<String> = []

	static func id(_ ip:IpAddr, _ depth: Int) -> String {
		"\(ip);\(depth)"
	}

	nonisolated var id:String { Node.id(ip, depth) }

	init(_ ip: IpAddr, _ depth:Int) {
		self.ip = ip
		self.depth = depth
		self.firstSeen = Date().timeIntervalSince1970
		self.lastSeen = firstSeen
	}

	var asDot: String {
		"ToDo"
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
