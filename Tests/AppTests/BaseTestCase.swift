import XCTVapor

@testable import Api
@testable import App
@testable import Core

/// Base class that spins up the Vapor application in testing mode.
/// Tests inherit from this to get a fully configured in-memory app
/// with migrations applied on SQLite.

class BaseTestCase: XCTestCase {
	var app: Application!

	/// Ensure the logging system is configured only once for the entire process
	private static var didBootstrapLogging = false

	/// Configure the logging system once for all tests. XCTest will call this
	/// method for each subclass so we guard against repeated bootstrap calls.
	override class func setUp() {
		super.setUp()
		if !didBootstrapLogging {
			LoggingSystem.flowpay()
			didBootstrapLogging = true
		}
	}

	/// Creates the application and runs migrations before each test.
	override func setUp() async throws {
		try await super.setUp()
		app = try await Application.make(.testing)
		try configure(app)
		try await app.autoRevert()
		try await app.autoMigrate()
	}

	/// Shuts the application down and reverts the database after each test.
	override func tearDown() async throws {
		try await app.autoRevert()
		try await app.asyncShutdown()
		try await super.tearDown()
	}
}
