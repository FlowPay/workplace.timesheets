import Fluent
import Foundation
import Vapor

/// Fluent model representing a worker (employee) imported from timesheets
public final class Worker: Model, Content {
	/// Database table name
	public static let schema = "workers"

	/// Unique identifier
	@ID(custom: "id", generatedBy: .user) public var id: UUID?

	/// Full name of the employee
	@OptionalField(key: "full_name") public var fullName: String?

	/// Optional email address
	@OptionalField(key: "email") public var email: String?

	/// Optional team reference
	@OptionalField(key: "team") public var team: String?

	/// Optional role reference
	@OptionalField(key: "role") public var role: String?

	/// Timestamp marking logical deletion (archiving)
	@Timestamp(key: "archived_at", on: .delete) public var archivedAt: Date?

	/// Creation timestamp
	@Timestamp(key: "created_at", on: .create) public var createdAt: Date?

	/// Update timestamp
	@Timestamp(key: "updated_at", on: .update) public var updatedAt: Date?

	/// Default initializer
	public init() {
	}
}
