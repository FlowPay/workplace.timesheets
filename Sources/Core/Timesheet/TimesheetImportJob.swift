import Fluent
import Vapor
import Queues

/// Background job responsible for parsing and normalizing a timesheet file.
public struct TimesheetImportJob: AsyncJob {
    /// Payload carrying batch identifier and file path
    public struct Payload: Codable {
        public let batchID: UUID
        public let path: String
        public init(batchID: UUID, path: String) {
            self.batchID = batchID
            self.path = path
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
            let rows = try TimesheetParser().parse(at: payload.path)
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
