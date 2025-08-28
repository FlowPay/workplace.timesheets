import Core
import Fluent
import Queues
import Vapor

/// Background job responsible for parsing and normalizing a timesheet file.
public struct TimesheetImportJob: AsyncJob {
	/// Payload carrying batch identifier and remote file reference
	public struct Payload: Codable {
		/// Identifier of the batch to process
		public let batchID: UUID
		/// Identifier of the file stored on aml.file
		public let fileID: UUID

		public init(batchID: UUID, fileID: UUID) {
			self.batchID = batchID
			self.fileID = fileID
		}
	}

	/// Default initializer
	public init() {}

	/// Executes the job
	public func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
		let db = context.application.db
		guard let batch = try await ImportBatch.find(payload.batchID, on: db) else {
			context.logger.error("Batch not found")
			return
		}

		batch.status = .processing
		batch.startedAt = Date()
		try await batch.save(on: db)

		do {
			// Retrieve the remote file and store it temporarily on disk
			let data = try await context.application.fileAdapter.fetch(id: payload.fileID, client: context.application.client)
			let directory = context.application.directory.publicDirectory + "uploads/"
			try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
			let path = directory + "\(payload.batchID.uuidString).xlsx"
			try data.write(to: URL(fileURLWithPath: path))

			defer { try? FileManager.default.removeItem(atPath: path) }
			let rows = try TimesheetParser().parse(at: path)
			let normalized = TimesheetNormalizer().normalize(rows)
			var ok = 0

			for entry in normalized {
				let worker: Worker
				if let existing = try await Worker.query(on: db).filter(\.$fullName == entry.workerName).first() {
					worker = existing
				} else {
					let key = entry.workerName.replacingOccurrences(of: " ", with: ".").lowercased()
					let newWorker = Worker(employeeKey: key, fullName: entry.workerName)
					try await newWorker.save(on: db)
					worker = newWorker
				}

				let timeEntry = TimeEntry(
					workerID: try worker.requireID(),
					batchID: batch.id,
					date: entry.date,
					startAt: entry.start,
					endAt: entry.end
				)
				try await timeEntry.save(on: db)

				for br in entry.breaks {
					let b = Break(
						timeEntryID: try timeEntry.requireID(),
						workerID: try worker.requireID(),
						startAt: br.start,
						endAt: br.end
					)
					try await b.save(on: db)
				}
				ok += 1
			}

			batch.rowsTotal = rows.count
			batch.rowsOk = ok
			batch.status = .completed
			batch.finishedAt = Date()
			try await batch.save(on: db)
		} catch {
			batch.status = .failed
			batch.finishedAt = Date()
			try? await batch.save(on: db)
			context.logger.error("Timesheet import failed: \(error)")
		}
	}

	/// Called when the job throws an error
	public func error(_ context: QueueContext, _ payload: Payload, _ error: Error) async throws {
		context.logger.error("Job error: \(error)")
	}
}
