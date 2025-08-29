import Fluent
import Foundation
import Vapor

/// Represents a time-off interval for a worker.
public final class Leave: Model, Content {
    /// Database table name
    public static let schema = "leaves"

    /// Unique identifier
    @ID(key: .id) public var id: UUID?

    /// Reference to the worker owning the leave
    @Parent(key: "worker_id") public var worker: Worker

    /// Identifier of the corresponding record on Microsoft Graph
    @Field(key: "graph_id") public var graphID: String

    /// Leave start timestamp
    @Field(key: "start_at") public var startAt: Date

    /// Leave end timestamp
    @Field(key: "end_at") public var endAt: Date

    /// Type of leave (e.g. Vacation, Sick)
    @Field(key: "type") public var type: String

    /// Creation timestamp
    @Timestamp(key: "created_at", on: .create) public var createdAt: Date?

    /// Update timestamp
    @Timestamp(key: "updated_at", on: .update) public var updatedAt: Date?

    /// Default initializer
    public init() {}

    /// Creates a new leave interval
    /// - Parameters:
    ///   - workerID: Identifier of the worker
    ///   - graphID: External identifier from Microsoft Graph
    ///   - startAt: Leave start
    ///   - endAt: Leave end
    ///   - type: Reason or category of the leave
    public init(workerID: UUID, graphID: String, startAt: Date, endAt: Date, type: String) {
        self.$worker.id = workerID
        self.graphID = graphID
        self.startAt = startAt
        self.endAt = endAt
        self.type = type
    }
}
