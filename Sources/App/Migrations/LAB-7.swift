import Core
import Fluent
import Foundation
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

                // import_batches table
                let status = try await database.enum("import_batch_status")
                        .case("queued")
                        .case("processing")
                        .case("completed")
                        .case("completed_with_errors")
                        .case("failed")
                        .create()

                try await database.schema("import_batches")
                        .id()
                        .field("filename", .string)
                        .field("uploaded_by", .string)
                        .field("rows_total", .int, .required)
                        .field("rows_ok", .int, .required)
                        .field("rows_error", .int, .required)
                        .field("status", status, .required)
                        .field("started_at", .datetime)
                        .field("finished_at", .datetime)
                        .field("created_at", .datetime)
                        .field("updated_at", .datetime)
                        .create()

                // time_entries table
                try await database.schema("time_entries")
                        .id()
                        .field("worker_id", .uuid, .required, .references("workers", "id"))
                        .field("batch_id", .uuid, .references("import_batches", "id", onDelete: .cascade))
                        .field("date", .date, .required)
                        .field("start_at", .datetime, .required)
                        .field("end_at", .datetime, .required)
                        .field("created_at", .datetime)
                        .field("updated_at", .datetime)
                        .create()

                // breaks table
                try await database.schema("breaks")
                        .id()
                        .field("time_entry_id", .uuid, .required, .references("time_entries", "id", onDelete: .cascade))
                        .field("worker_id", .uuid, .required, .references("workers", "id", onDelete: .cascade))
                        .field("start_at", .datetime, .required)
                        .field("end_at", .datetime, .required)
                        .field("created_at", .datetime)
                        .field("updated_at", .datetime)
                        .create()
        }

        /// Revert all tables
        func revert(on database: Database) async throws {
                try await database.schema("breaks").delete()
                try await database.schema("time_entries").delete()
                try await database.schema("import_batches").delete()
                try await database.enum("import_batch_status").delete()
                try await database.schema("workers").delete()
        }
}
