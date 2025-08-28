import Api
import Core
import FluentUtilities
import Foundation
import Queues
import ServerUtilities
import Vapor

/// Configure the given application instance.
/// - Parameter app: The application to configure.
/// - Throws: Any error while configuring components.
public func configure(_ app: Application) throws {

	/// Configure basic service information
	app.serviceName = Configuration.shared.serviceName
	app.context = .legacy

	/// Configure the HTTP server
	app.http.server.configuration.port = Configuration.shared.servicePort
	app.http.server.configuration.serverName = Configuration.shared.serviceName
	app.http.server.configuration.reuseAddress = true
	app.http.server.configuration.hostname = "0.0.0.0"
	app.http.server.configuration.logger.logLevel = Configuration.shared.logLevel

	/// Apply general settings
	app.routes.defaultMaxBodySize = "10mb"
	app.logger.logLevel = Configuration.shared.logLevel

	/// Initialize database connections
	try init_database(app: app)

	/// Configure MongoDB logging if available
	if let mongoString = Configuration.shared.requestsMongoString {
		app.logger.trace("Request mongo string found")

		try app.databases.use(
			.mongo(connectionString: mongoString),
			as: .requestsDB,
			isDefault: false
		)

		app.middleware.use(RequestRecordMiddleware(databaseID: .requestsDB))
		app.logger.info("HTTP requests will be stored in mongoDB")
	}

	/// Register middlewares
	app.middleware.use(RouteLoggingMiddleware.init(logLevel: .info))
	app.middleware.use(DatabaseMiddleware())
	app.middleware.use(ErrorResponseMiddleware())

        /// Register routes
        try routes(app: app)

        /// Output all registered routes for debugging
        app.routes.all.forEach { print($0) }

        /// Configure Microsoft Graph client using OAuth2 client credentials (required)
        let provider = ClientCredentialsTokenProvider(tenantId: Configuration.shared.msGraphTenantId,
                                                      clientId: Configuration.shared.msGraphClientId,
                                                      clientSecret: Configuration.shared.msGraphClientSecret)
        app.graphClient = MicrosoftGraphClient(baseURL: Configuration.shared.msGraphURL, tokenProvider: provider)

        /// Schedule periodic synchronization using an in-process job
        app.queues.schedule(GraphSyncJob()).hourly().at(0)
        try app.queues.startScheduledJobs()
}
