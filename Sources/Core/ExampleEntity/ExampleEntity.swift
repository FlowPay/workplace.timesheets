import Fluent
import Foundation
import Vapor

/// Fluent model representing the example entity stored in the database
public final class ExampleEntity: Model {
	/// Database table name
	public static let schema = "example_entities"

	/// Unique identifier
	@ID(key: .id) public var id: UUID?

	/// Example string field
	@Field(key: "string_example") public var stringExample: String
	/// Optional integer field
	@OptionalField(key: "optional_integer_example") public var optionalIntegerExample: Int?
	/// Enum field example
	@Enum(key: "enum_example") public var enumExample: ExampleEnum

	/// Creation timestamp
	@Timestamp(key: "created_at", on: .create) public var createdAt: Date?
	/// Update timestamp
	@Timestamp(key: "updated_at", on: .update) public var updatedAt: Date?
	/// Deletion timestamp
	@Timestamp(key: "deleted_at", on: .delete) public var deletedAt: Date?

	/// Default initializer
	public init() {}

	/// Create a new example entity
	/// - Parameters:
	///   - stringExample: Example string value
	///   - optionalIntegerExample: Optional integer value
	///   - enumExample: Example enumeration value
	public init(stringExample: String, optionalIntegerExample: Int? = nil, enumExample: ExampleEnum) {
		self.stringExample = stringExample
		self.optionalIntegerExample = optionalIntegerExample
		self.enumExample = enumExample
	}
}

extension ExampleEntity {
	/// Sample enumeration
	public enum ExampleEnum: String, Codable {
		case xyz
		case abcd
	}
}
