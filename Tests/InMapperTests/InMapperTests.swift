import XCTest
@testable import InMapper

final class InMapperTests: XCTestCase {
    func test255() async throws {
		let ping = Ping()
		let result = await ping.send("asdf.com", 255)
		XCTAssertEqual(.success, result)
	}

	func testAsdf() async throws {
		let ips = ["asdf.com", "1.1.1.1", "8.8.8.8"]
		let map = try await InMapper()
		for ip in ips {
			let node = try await map.test(ip)
			XCTAssertNotNil(node)
			XCTAssert(map.nodes.contains(node!))
			XCTAssert(map.edges.contains(where: {$0.destination == node!.ip}))
		}

		print(map.asDot)
	}
}
