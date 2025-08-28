import Fluent
import Foundation
import Vapor

extension ExampleEntity {
	/// Retrieve all example entities from the database
	/// - Parameter db: Database instance
	/// - Returns: Array of stored example entities
	public static func list(from db: Database) async throws -> [ExampleEntity] {
		let query = ExampleEntity.query(on: db)
		let results = try await query.all()
		return results
	}
}
