import Vapor
import XCTVapor

@testable import Api
@testable import App
@testable import Core

/// Tests for ImportBatch endpoints
final class ImportBatchTests: BaseTestCase {
	/// Ensures that uploading a timesheet returns a batch in queued status
	/// and that the batch can be retrieved via GET endpoint.
	/// The assertions verify HTTP codes and initial counter values.
	func testUploadAndRetrieveBatch() throws {
		let examples = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.appendingPathComponent("examples")
		let fileURL = examples.appendingPathComponent("TimeSheetExport_2025-7-1_TO_2025-8-7_TEAM_7331a68b-6a8b-475f-9286-b78c42c78543_dd159988a3ba498991157759e26f5672.xlsx")
		app.amlFileClient = TestAmlFileClient(fileURL: fileURL)
		let fileID = UUID()

                try app.test(
                        .POST,
                        "/imports/timesheet",
                        beforeRequest: { req in
                                // Only the file identifier is required by the API
                                try req.content.encode(ImportBatchDTO.UploadInput(fileID: fileID))
                        },
                        afterResponse: { res in
                                XCTAssertEqual(res.status, .accepted)
                                let batch = try res.content.decode(ImportBatch.self)
				XCTAssertEqual(batch.status, .queued)
				XCTAssertEqual(batch.rowsTotal, 0)

				try app.test(
					.GET,
					"/imports/\(batch.id!)",
					afterResponse: { getRes in
						XCTAssertEqual(getRes.status, .ok)
					}
				)
			}
		)
	}
}
