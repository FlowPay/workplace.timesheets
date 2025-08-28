import Foundation
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
		let fileManager = FileManager.default
		let dbPath = fileManager.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".sqlite").path
		if fileManager.fileExists(atPath: dbPath) {
			try? fileManager.removeItem(atPath: dbPath)
		}
		setenv("SQLITE_PATH", dbPath, 1)
		app = try await Application.make(.testing)
		try configure(app)
		try await app.autoMigrate()

		// Register default aml.file client returning example spreadsheet to avoid fatal errors in tests
		let examples = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.appendingPathComponent("examples")
		let fileURL = examples.appendingPathComponent("TimeSheetExport_2025-7-1_TO_2025-8-7_TEAM_7331a68b-6a8b-475f-9286-b78c42c78543_dd159988a3ba498991157759e26f5672.xlsx")
		app.fileAdapter = TestAmlFileClient(fileURL: fileURL)
	}

	/// Shuts the application down after each test and removes the temporary database file.
	override func tearDown() async throws {
		if let cPath = getenv("SQLITE_PATH") {
			let path = String(cString: cPath)
			try? FileManager.default.removeItem(atPath: path)
			unsetenv("SQLITE_PATH")
		}
		try await app.asyncShutdown()
		try await super.tearDown()
	}
}
