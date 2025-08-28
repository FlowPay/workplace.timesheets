import Core
import Fluent
import FluentPostgresDriver
import Foundation
import Vapor

/// Initial database migration creating the example table
struct FPY475: AsyncMigration {
	/// Name of the migration task
	let name = "FPY-475"

	/// Create schema and enum
	func prepare(on database: any FluentKit.Database) async throws {
		let exampleEnum = try await database.enum("example_enum")
			.case("xyz")
			.case("abcd")
			.create()

		try await database.schema("example_entities")
			.id()
			.field("string_example", .string, .required)
			.field("optional_integer_example", .int)
			.field("enum_example", exampleEnum, .required)
			.field("created_at", .datetime)
			.field("updated_at", .datetime)
			.field("deleted_at", .datetime)
			.create()
	}

	/// Revert migration
	func revert(on database: any FluentKit.Database) async throws {
		try await database.schema("example_entities").delete()
		try await database.enum("example_enum").delete()
	}
}
