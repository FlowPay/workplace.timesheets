import Fluent
import FluentSQL

enum UpsertError: Error { case notSQLDatabase }

/// Upsert extension for arrays of Fluent models
extension Array where Element: Model {
	/// Upsert an array of Fluent models using the given conflict columns.
	/// - Parameters:
	///   - models: The models to insert or update.
	///   - db: Database connection (must support SQLDatabase).
	///   - conflictColumns: Columns used for the ON CONFLICT target. Defaults to `id`.
	///   - excludeFromUpdates: Columns to exclude from the UPDATE set on conflict (in addition to conflict columns).
	public func upsert(
		on db: Database,
		conflictColumns: [String] = ["id"],
		excludeFromUpdates: Set<String> = ["id", "created_at"]
	) async throws {
		guard !isEmpty else { return }
		guard let sql = db as? SQLDatabase else { throw UpsertError.notSQLDatabase }

		// Compute update set from model keys dynamically (DB column names)
		let allColumns = Element.keys.map(\.description)
		let excluded = excludeFromUpdates.union(conflictColumns)
		let updateColumns = allColumns.filter { !excluded.contains($0) }

		try await sql
			.insert(into: Element.schema)
			.fluentModels(self)
			.onConflict(with: conflictColumns) { builder in
				updateColumns.reduce(builder) { $0.set(excludedValueOf: $1) }
			}
			.run()
	}
}
