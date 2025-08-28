import Fluent
import Foundation
import Vapor

/// Fluent model representing a worker (employee) imported from timesheets
public final class Worker: Model, Content {
    /// Database table name
    public static let schema = "workers"

    /// Unique identifier
    @ID(key: .id) public var id: UUID?

    /// External employee key (email, UPN or employee code)
    @Field(key: "employee_key") public var employeeKey: String

    /// Full name of the employee
    @Field(key: "full_name") public var fullName: String

    /// Optional team reference
    @OptionalField(key: "team") public var team: String?

    /// Optional role reference
    @OptionalField(key: "role") public var role: String?

    /// Timestamp marking logical deletion (archiving)
    @Timestamp(key: "archived_at", on: .none) public var archivedAt: Date?

    /// Creation timestamp
    @Timestamp(key: "created_at", on: .create) public var createdAt: Date?

    /// Update timestamp
    @Timestamp(key: "updated_at", on: .update) public var updatedAt: Date?

    /// Default initializer
    public init() {}

    /// Creates a new worker instance
    /// - Parameters:
    ///   - employeeKey: Unique external key
    ///   - fullName: Full name of the employee
    ///   - team: Optional team
    ///   - role: Optional role
    public init(employeeKey: String, fullName: String, team: String? = nil, role: String? = nil) {
        self.employeeKey = employeeKey
        self.fullName = fullName
        self.team = team
        self.role = role
    }
}
