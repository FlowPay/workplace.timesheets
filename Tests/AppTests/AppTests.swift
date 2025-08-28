import FluentSQLiteDriver
import IBANUtilities
import XCTVapor

@testable import Api
@testable import App
@testable import Core

/// Basic application tests
final class AppTests: BaseTestCase {

	/// Validate creation endpoint
	func testCreateExample() throws {
		let exampleDTO = ExampleEntity.Input(
			stringExample: "hello world",
			optionalIntegerExample: nil,
			enumExample: .abcd
		)

		try self.app.test(
			.POST,
			"/examples",
			beforeRequest: { request in
				try request.content.encode(exampleDTO)
			},
			afterResponse: { response in
				XCTAssertEqual(response.status, .created)

				let content = try response.content.decode(ExampleEntity.Output.self)
				XCTAssertEqual(content.stringExample, exampleDTO.stringExample)
				XCTAssertEqual(content.enumExample, exampleDTO.enumExample)
			}
		)
	}

	/// Validate listing endpoint
	func testGetListExamples() throws {
		try self.app.test(
			.GET,
			"/examples",
			afterResponse: { response in
				XCTAssertEqual(response.status, .ok)
			}
		)
	}
}
