import XCTest
@testable import InMapper

final class InMapperTests: XCTestCase {
    func test255() async throws {
		let ping = Ping()
		let result = await ping.send("asdf.com", 255)
		XCTAssertEqual(.success, result)
	}

	func testAsdf() async throws {
		let ip = "asdf.com"
		let map = try await InMapper()
		let node = await map.test(ip)
		XCTAssertNotNil(node)
		let nodes = map.nodes.get(ip)
		XCTAssertEqual(nodes.count,1)
		XCTAssertEqual(nodes[0].id,node!.id)
		let result = try map.nodes.path(ip).map{$0.ip}.joined(separator: "\n")
		let expected = """
			192.168.112.1
			192.168.31.254
			107.131.124.1
			71.148.149.196
			12.242.105.110
			12.122.114.5
			64.125.12.117
			64.125.12.117->asdf.com
			64.125.12.117->asdf.com->asdf.com
			64.125.21.211
			64.125.20.213
			208.184.59.201
			66.33.200.3
			66.33.200.8
			asdf.com
			"""
	}
}
