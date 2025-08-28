import Api
import Foundation
import ServerUtilities
import Vapor

/// Register your application's routes here.
/// - Parameter app: The application.
/// - Throws: Any error that occurs while registering routes.
func routes(app: Application) throws {

	try app.register(collection: ExampleController())

	app.registerRequestsRoutes()
	try app.registerDebugRoutes()
}
