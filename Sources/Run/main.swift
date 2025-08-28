import App
import ServerUtilities
import Vapor

/// Detect execution environment
var env = try Environment.detect()
/// Configure global logging
LoggingSystem.flowpay()
/// Create application instance
let app = try await Application.make(env)

defer { app.shutdown() }

do {
	/// Configure and run the application
	try configure(app)
	try await app.execute()
} catch {
	/// Dump error information and terminate
	var messageString = error.localizedDescription
	if !env.isRelease {
		messageString = messageString + "\n" + String(reflecting: error)
	}
	let message: Logger.Message = .init(stringLiteral: messageString)
	app.logger.critical(message)
}
