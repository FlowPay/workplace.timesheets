import Api
import Foundation
import ServerUtilities
import Vapor

/// Register your application's routes here.
/// - Parameter app: The application.
/// - Throws: Any error that occurs while registering routes.
func routes(app: Application) throws {

        try app.register(collection: WorkerController())
        try app.register(collection: TimesheetController())
        try app.register(collection: SyncController())

	app.registerRequestsRoutes()
	try app.registerDebugRoutes()
}
