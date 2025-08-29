import Fluent
import Foundation
import Vapor

/// Represents a break interval within a time entry.
public final class Break: Model, Content {
	/// Database table name
	public static let schema = "breaks"

	/// Unique identifier
	@ID(key: .id) public var id: UUID?

	/// Parent time entry
	@Parent(key: "time_entry_id") public var timeEntry: TimeEntry

	/// Worker reference for convenience
	@Parent(key: "worker_id") public var worker: Worker

    /// Identifier of the corresponding break on Microsoft Graph
    @Field(key: "graph_id") public var graphID: String

	/// Break start timestamp
	@Field(key: "start_at") public var startAt: Date

	/// Break end timestamp
	@Field(key: "end_at") public var endAt: Date

	/// Creation timestamp
	@Timestamp(key: "created_at", on: .create) public var createdAt: Date?

	/// Update timestamp
	@Timestamp(key: "updated_at", on: .update) public var updatedAt: Date?

	/// Default initializer
	public init() {}

	/// Creates a new break interval
	/// - Parameters:
	///   - timeEntryID: Related time entry identifier
	///   - workerID: Worker identifier
    ///   - graphID: External break identifier from Microsoft Graph
    ///   - startAt: Break start
    ///   - endAt: Break end
    public init(timeEntryID: UUID, workerID: UUID, graphID: String, startAt: Date, endAt: Date) {
        self.$timeEntry.id = timeEntryID
        self.$worker.id = workerID
        self.graphID = graphID
        self.startAt = startAt
        self.endAt = endAt
    }
}
