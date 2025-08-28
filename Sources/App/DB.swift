import Core
import Fluent
import FluentMongoDriver
import FluentPostgresDriver
import FluentSQLiteDriver
import FluentUtilities
import Foundation
import ServerUtilities
import Vapor

/// Initialize database connections and migrations
/// - Parameter app: Application instance
func init_database(app: Application) throws {

	if app.environment == .testing {
		app.logger.info("Running in testing mode, using SQLite")
		try sqlite_init(app: app)
	} else {
		try postgres_init(app: app)
	}

	app.migrations.add([
		FPY475()
	])
}

/// Configure PostgreSQL database
/// - Parameter app: Application instance
func postgres_init(app: Application) throws {
	/// TLS settings for the connection
	let tlsConfiguration: PostgresNIO.PostgresConnection.Configuration.TLS = .disable

	app.databases.use(
		.postgres(
			configuration: .init(
				hostname: Configuration.shared.dbHostname,
				port: Configuration.shared.dbPort,
				username: Configuration.shared.dbUsername,
				password: Configuration.shared.dbPassword,
				database: Configuration.shared.dbName,
				tls: tlsConfiguration
			)
		),
		as: .psql,
		isDefault: true
	)
}

/// Configure SQLite database used during tests
/// - Parameter app: Application instance
func sqlite_init(app: Application) throws {
	/// Database configuration
	var configuration: SQLiteConfiguration

	if let filepath = Configuration.shared.sqlitePath {
		app.logger.info("Use SQLite file: \(filepath)")
		configuration = .file(filepath)
	} else {
		app.logger.debug("SQLite file path not set.")
		app.logger.warning("SQLite will run in memory")
		configuration = .memory
	}

	app.databases.use(.sqlite(configuration), as: .sqlite, isDefault: true)
}
