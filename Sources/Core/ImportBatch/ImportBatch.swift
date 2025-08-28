import Fluent
import Foundation
import Vapor

/// Tracks the status of an uploaded timesheet file
public final class ImportBatch: Model, Content {
    /// Database table name
    public static let schema = "import_batches"

    /// Unique identifier
    @ID(key: .id) public var id: UUID?

    /// Optional original filename
    @OptionalField(key: "filename") public var filename: String?

    /// Optional identifier of the uploader
    @OptionalField(key: "uploaded_by") public var uploadedBy: String?

    /// Total number of rows parsed from the file
    @Field(key: "rows_total") public var rowsTotal: Int

    /// Number of rows successfully imported
    @Field(key: "rows_ok") public var rowsOk: Int

    /// Number of rows with errors
    @Field(key: "rows_error") public var rowsError: Int

    /// Status of the batch
    @Enum(key: "status") public var status: Status

    /// Processing start timestamp
    @Timestamp(key: "started_at", on: .none) public var startedAt: Date?

    /// Processing completion timestamp
    @Timestamp(key: "finished_at", on: .none) public var finishedAt: Date?

    /// Creation timestamp
    @Timestamp(key: "created_at", on: .create) public var createdAt: Date?

    /// Update timestamp
    @Timestamp(key: "updated_at", on: .update) public var updatedAt: Date?

    /// Default initializer
    public init() {}

    /// Create a new batch instance with default counters
    public init(filename: String?, uploadedBy: String?) {
        self.filename = filename
        self.uploadedBy = uploadedBy
        self.rowsTotal = 0
        self.rowsOk = 0
        self.rowsError = 0
        self.status = .queued
    }

    /// Possible statuses for an import batch
    public enum Status: String, Codable {
        case queued
        case processing
        case completed
        case completedWithErrors = "completed_with_errors"
        case failed
    }
}
