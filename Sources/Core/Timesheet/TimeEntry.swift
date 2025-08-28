import Fluent
import Foundation
import Vapor

/// Represents a normalized working interval for a worker.
public final class TimeEntry: Model, Content {
	/// Database table name
	public static let schema = "time_entries"

	/// Unique identifier
	@ID(key: .id) public var id: UUID?

	/// Reference to the worker owning the entry
	@Parent(key: "worker_id") public var worker: Worker

	/// Optional reference to the import batch that produced the entry
	@OptionalParent(key: "batch_id") public var batch: ImportBatch?

	/// Date of the entry (shift day)
	@Field(key: "date") public var date: Date

	/// Clock-in timestamp
	@Field(key: "start_at") public var startAt: Date

	/// Clock-out timestamp
	@Field(key: "end_at") public var endAt: Date

	/// Related breaks detected within this time entry
	@Children(for: \.$timeEntry) public var breaks: [Break]

	/// Creation timestamp
	@Timestamp(key: "created_at", on: .create) public var createdAt: Date?

	/// Update timestamp
	@Timestamp(key: "updated_at", on: .update) public var updatedAt: Date?

	/// Default initializer
	public init() {}

	/// Creates a new time entry
	/// - Parameters:
	///   - workerID: Identifier of the worker
	///   - batchID: Import batch identifier
	///   - date: Day of the entry
	///   - startAt: Clock-in timestamp
	///   - endAt: Clock-out timestamp
	public init(workerID: UUID, batchID: UUID?, date: Date, startAt: Date, endAt: Date) {
		self.$worker.id = workerID
		self.$batch.id = batchID
		self.date = date
		self.startAt = startAt
		self.endAt = endAt
	}
}
