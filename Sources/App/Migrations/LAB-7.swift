import Core
import Fluent
import Foundation
import SQLKit
import Vapor

/// Creates core tables for timesheet management.
struct LAB7: AsyncMigration {
	/// Migration name
	let name = "LAB-7"

	/// Prepare database schema
	func prepare(on database: Database) async throws {
		// workers table
		try await database.schema("workers")
			.id()
			.field("employee_key", .string, .required)
			.field("full_name", .string, .required)
			.field("team", .string)
			.field("role", .string)
			.field("archived_at", .datetime)
			.field("created_at", .datetime)
			.field("updated_at", .datetime)
			.unique(on: "employee_key")
			.create()

		// time_entries table
		try await database.schema("time_entries")
			.id()
			.field("worker_id", .uuid, .required, .references("workers", "id"))
			.field("graph_id", .string, .required)
			.field("date", .date, .required)
			.field("start_at", .datetime, .required)
			.field("end_at", .datetime, .required)
			.field("created_at", .datetime)
			.field("updated_at", .datetime)
			.unique(on: "graph_id")
			.create()

		// breaks table
		try await database.schema("breaks")
			.id()
			.field("time_entry_id", .uuid, .required, .references("time_entries", "id", onDelete: .cascade))
			.field("worker_id", .uuid, .required, .references("workers", "id", onDelete: .cascade))
			.field("graph_id", .string, .required)
			.field("start_at", .datetime, .required)
			.field("end_at", .datetime, .required)
			.field("created_at", .datetime)
			.field("updated_at", .datetime)
			.unique(on: "graph_id")
			.create()

		// leaves table
		try await database.schema("leaves")
			.id()
			.field("worker_id", .uuid, .required, .references("workers", "id"))
			.field("graph_id", .string, .required)
			.field("start_at", .datetime, .required)
			.field("end_at", .datetime, .required)
			.field("type", .string, .required)
			.field("created_at", .datetime)
			.field("updated_at", .datetime)
			.unique(on: "graph_id")
			.create()

		// planned_shifts table
		try await database.schema("planned_shifts")
			.id()
			.field("worker_id", .uuid, .required, .references("workers", "id"))
			.field("graph_id", .string, .required)
			.field("date", .date, .required)
			.field("start_at", .datetime, .required)
			.field("end_at", .datetime, .required)
			.field("created_at", .datetime)
			.field("updated_at", .datetime)
			.unique(on: "graph_id")
			.create()

		// planned_breaks table
		try await database.schema("planned_breaks")
			.id()
			.field("planned_shift_id", .uuid, .required, .references("planned_shifts", "id", onDelete: .cascade))
			.field("worker_id", .uuid, .required, .references("workers", "id", onDelete: .cascade))
			.field("start_at", .datetime, .required)
			.field("end_at", .datetime, .required)
			.field("created_at", .datetime)
			.field("updated_at", .datetime)
			.create()

		// Add helpful indexes via raw SQL
		if let sql = database as? SQLDatabase {
			try? await sql.raw("CREATE INDEX IF NOT EXISTS workers_employee_key_idx ON workers (employee_key);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS workers_full_name_idx ON workers (full_name);").run()

			try? await sql.raw("CREATE INDEX IF NOT EXISTS time_entries_worker_id_idx ON time_entries (worker_id);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS time_entries_date_idx ON time_entries (date);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS time_entries_start_at_idx ON time_entries (start_at);").run()

			try? await sql.raw("CREATE INDEX IF NOT EXISTS breaks_time_entry_id_idx ON breaks (time_entry_id);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS breaks_worker_id_idx ON breaks (worker_id);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS breaks_start_at_idx ON breaks (start_at);").run()

			try? await sql.raw("CREATE INDEX IF NOT EXISTS leaves_worker_id_idx ON leaves (worker_id);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS leaves_start_at_idx ON leaves (start_at);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS leaves_end_at_idx ON leaves (end_at);").run()

			try? await sql.raw("CREATE INDEX IF NOT EXISTS planned_shifts_worker_id_idx ON planned_shifts (worker_id);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS planned_shifts_date_idx ON planned_shifts (date);").run()

			try? await sql.raw("CREATE INDEX IF NOT EXISTS planned_breaks_planned_shift_id_idx ON planned_breaks (planned_shift_id);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS planned_breaks_worker_id_idx ON planned_breaks (worker_id);").run()
			try? await sql.raw("CREATE INDEX IF NOT EXISTS planned_breaks_start_at_idx ON planned_breaks (start_at);").run()
		}
	}

	/// Revert all tables
	func revert(on database: Database) async throws {
		try await database.schema("breaks").delete()
		try await database.schema("leaves").delete()
		try await database.schema("planned_breaks").delete()
		try await database.schema("planned_shifts").delete()
		try await database.schema("time_entries").delete()
		try await database.schema("workers").delete()
	}
}
