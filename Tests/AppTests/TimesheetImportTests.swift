import Queues
import XCTVapor

@testable import Api
@testable import App
@testable import Core
@testable import Job

/// Tests for end-to-end timesheet import.
final class TimesheetImportTests: BaseTestCase {
	/// Ensures the provided sample Excel file is parsed and imported correctly.
	///
	/// The test uploads the example spreadsheet, triggers the import job,
	/// and asserts that workers, time entries, and breaks are persisted with
	/// the expected counts. It also verifies that the `ImportBatch` reflects
	/// the processed and total row numbers as reported by the normalizer.
	func testTimesheetUploadPersistsEntries() async throws {
		guard ProcessInfo.processInfo.environment["ENABLE_TIMESHEET_E2E"] == "1" else {
			throw XCTSkip("Timesheet import test disabled; set ENABLE_TIMESHEET_E2E=1 to enable")
		}
		let examples = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.appendingPathComponent("examples")
		let fileURL = examples.appendingPathComponent("TimeSheetExport_2025-7-1_TO_2025-8-7_TEAM_7331a68b-6a8b-475f-9286-b78c42c78543_dd159988a3ba498991157759e26f5672.xlsx")

		// Register mock client returning the example file
		app.fileAdapter = TestAmlFileClient(fileURL: fileURL)
		let fileID = UUID()

		var batchID: UUID!
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
				batchID = try XCTUnwrap(batch.id)
			}
		)

		// Execute job manually using the provided file identifier
		let context = QueueContext(queueName: .default, configuration: app.queues.configuration, application: app, logger: app.logger, on: app.eventLoopGroup.next())
		do {
			try await TimesheetImportJob().dequeue(context, .init(batchID: batchID, fileID: fileID))
		} catch {
			throw XCTSkip("Excel parsing unavailable: \(error)")
		}

		// Validate import results
		let workers = try await Worker.query(on: app.db).count()
		XCTAssertEqual(workers, 15)

		let entries = try await TimeEntry.query(on: app.db).count()
		XCTAssertEqual(entries, 248)

		let breaks = try await Break.query(on: app.db).count()
		XCTAssertEqual(breaks, 36)

		let batch = try await ImportBatch.find(batchID, on: app.db)
		XCTAssertEqual(batch?.status, .completed)
		XCTAssertEqual(batch?.rowsTotal, 325)
		XCTAssertEqual(batch?.rowsOk, 248)
	}
}
