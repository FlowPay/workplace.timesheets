import Foundation
import Vapor

@testable import Core

/// Test implementation returning a static Excel file bundled with the tests.
struct TestAmlFileClient: FileAdapterProtocol {
	/// Location of the Excel example on disk
	let fileURL: URL

	/// Returns the file contents regardless of the requested identifier.
	func fetch(id: UUID, client: Client) async throws -> Data {
		try Data(contentsOf: fileURL)
	}
}
