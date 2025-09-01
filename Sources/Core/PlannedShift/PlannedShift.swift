import Fluent
import Foundation
import Vapor

/// Represents a planned working interval (Shift) for a worker.
public final class PlannedShift: Model, Content {
    /// Database table name
    public static let schema = "planned_shifts"

    /// Unique identifier
    @ID(key: .id) public var id: UUID?

    /// Reference to the worker owning the shift
    @Parent(key: "worker_id") public var worker: Worker

    /// Identifier of the corresponding shift on Microsoft Graph
    @Field(key: "graph_id") public var graphID: String

    /// Display name of the shift (from Graph sharedShift.displayName)
    @OptionalField(key: "name") public var name: String?

    /// Day of the shift
    @Field(key: "date") public var date: Date

    /// Planned start timestamp
    @Field(key: "start_at") public var startAt: Date

    /// Planned end timestamp
    @Field(key: "end_at") public var endAt: Date

    /// Related planned breaks within this shift
    @Children(for: \.$plannedShift) public var breaks: [PlannedBreak]

    /// Creation timestamp
    @Timestamp(key: "created_at", on: .create) public var createdAt: Date?

    /// Update timestamp
    @Timestamp(key: "updated_at", on: .update) public var updatedAt: Date?

    /// Default initializer
    public init() {}

    /// Creates a new planned shift
    /// - Parameters:
    ///   - workerID: Identifier of the worker
    ///   - graphID: External identifier from Microsoft Graph
    ///   - date: Day of the shift
    ///   - startAt: Planned start timestamp
    ///   - endAt: Planned end timestamp
    public init(workerID: UUID, graphID: String, date: Date, startAt: Date, endAt: Date, name: String? = nil) {
        self.$worker.id = workerID
        self.graphID = graphID
        self.date = date
        self.startAt = startAt
        self.endAt = endAt
        self.name = name
    }
}

/// Represents a planned break belonging to a planned shift.
public final class PlannedBreak: Model, Content {
    /// Database table name
    public static let schema = "planned_breaks"

    /// Unique identifier
    @ID(key: .id) public var id: UUID?

    /// Parent planned shift
    @Parent(key: "planned_shift_id") public var plannedShift: PlannedShift

    /// Owner worker (for querying convenience and cascading deletions)
    @Parent(key: "worker_id") public var worker: Worker

    /// Planned break start
    @Field(key: "start_at") public var startAt: Date

    /// Planned break end
    @Field(key: "end_at") public var endAt: Date

    /// Creation timestamp
    @Timestamp(key: "created_at", on: .create) public var createdAt: Date?

    /// Update timestamp
    @Timestamp(key: "updated_at", on: .update) public var updatedAt: Date?

    /// Default initializer
    public init() {}

    /// Create a new planned break
    public init(plannedShiftID: UUID, workerID: UUID, start: Date, end: Date) {
        self.$plannedShift.id = plannedShiftID
        self.$worker.id = workerID
        self.startAt = start
        self.endAt = end
    }
}
