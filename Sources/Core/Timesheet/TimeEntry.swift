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

        /// Identifier of the corresponding record on Microsoft Graph
        @Field(key: "graph_id") public var graphID: String

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
        ///   - graphID: External identifier from Microsoft Graph
        ///   - date: Day of the entry
        ///   - startAt: Clock-in timestamp
        ///   - endAt: Clock-out timestamp
        public init(workerID: UUID, graphID: String, date: Date, startAt: Date, endAt: Date) {
                self.$worker.id = workerID
                self.graphID = graphID
                self.date = date
                self.startAt = startAt
                self.endAt = endAt
        }
}
