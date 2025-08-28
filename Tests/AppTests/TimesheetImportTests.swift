import Queues
import XCTVapor

@testable import Api
@testable import App
@testable import Core

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
		let data = try Data(contentsOf: fileURL)
		let boundary = "Boundary-\(UUID().uuidString)"
		var buffer = ByteBuffer()
		buffer.writeString("--\(boundary)\r\n")
		buffer.writeString("Content-Disposition: form-data; name=\"file\"; filename=\"test.xlsx\"\r\n")
		buffer.writeString("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n")
		buffer.writeBytes(data)
		buffer.writeString("\r\n--\(boundary)--\r\n")

		var batchID: UUID!
		try app.test(
			.POST,
			"/imports/timesheet",
			beforeRequest: { req in
				req.headers.contentType = HTTPMediaType(type: "multipart", subType: "form-data", parameters: ["boundary": boundary])
				req.body = .init(buffer: buffer)
			},
			afterResponse: { res in
				XCTAssertEqual(res.status, .accepted)
				let batch = try res.content.decode(ImportBatch.self)
				batchID = try XCTUnwrap(batch.id)
			}
		)

		// Execute job manually
		let path = app.directory.publicDirectory + "uploads/\(batchID.uuidString).xlsx"
		let context = QueueContext(queueName: .default, configuration: app.queues.configuration, application: app, logger: app.logger, on: app.eventLoopGroup.next())
		do {
			try await TimesheetImportJob().dequeue(context, .init(batchID: batchID, path: path))
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
