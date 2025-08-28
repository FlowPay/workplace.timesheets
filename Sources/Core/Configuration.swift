import FlowpayUtilities
import Foundation
import Vapor

public typealias Configuration = Application.Configuration

extension Application {

	/// Initialize the configuration logger
	public func initializeConfiguration() {
		Configuration.logger = logger
	}

	/// Container for global configuration values
	public struct Configuration {
		/// Logger used during configuration bootstrapping
		public fileprivate(set) static var logger = Logger(label: "Configuration Logger")
		/// Shared singleton instance
		public static let shared = Configuration()

		// MARK: - Service
		/// Port used by the HTTP server
		public let servicePort: Int
		/// Name of the running service
		public let serviceName: String
		/// Logging level for the service
		public let logLevel: Logger.Level

		// MARK: - Database
		/// Database username
		public let dbUsername: String
		/// Database password
		public let dbPassword: String
		/// Database host address
		public let dbHostname: String
		/// Database port
		public let dbPort: Int
		/// Database schema name
		public let dbName: String
		/// Optional path to a SQLite database file
		public let sqlitePath: String?
		/// Optional connection string for request logging database
		public let requestsMongoString: String?

		/// Initialize configuration by reading environment values
		init() {
			do {
				self.servicePort = Environment.process.retrieve("SERVICE_PORT", fallback: 5555)
				self.serviceName = Environment.process.retrieve("SERVICE_NAME", fallback: "service")
				self.logLevel = Environment.process.retrieve("LOG_LEVEL", fallback: .info)

				self.dbUsername = try Environment.process.retrieve("DB_USERNAME")
				self.dbPassword = try Environment.process.retrieve("DB_PASSWORD")
				self.dbHostname = try Environment.process.retrieve("DB_HOSTNAME")
				self.dbPort = try Environment.process.retrieve("DB_PORT")
				self.dbName = try Environment.process.retrieve("DB_SCHEMA")
				self.sqlitePath = try? Environment.process.retrieve("SQLITE_PATH")
				self.requestsMongoString = try? Environment.process.retrieve("REQUESTS_MONGO_STRING")

			} catch let error {
				/// Build an error message and terminate on failure
				let messageString = error.localizedDescription + "\n" + String(reflecting: error)
				Self.logger.critical(.init(stringLiteral: messageString))
				fatalError(messageString)
			}
		}
	}
}
