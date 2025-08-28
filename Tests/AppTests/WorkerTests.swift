import XCTVapor

@testable import Api
@testable import App
@testable import Core

/// Tests covering Worker CRUD operations
final class WorkerTests: BaseTestCase {
    /// Verifies that a worker can be created and retrieved via detail endpoint.
    /// The test asserts that the returned payload matches the input data
    /// and that the detail endpoint responds with HTTP 200.
    func testCreateAndGetWorker() throws {
        let input = Worker.Input(employeeKey: "user@example.com", fullName: "John Doe", team: nil, role: nil)

        try app.test(.POST, "/workers", beforeRequest: { req in
            try req.content.encode(input)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created)
            let output = try res.content.decode(Worker.Output.self)
            XCTAssertEqual(output.employeeKey, input.employeeKey)
            XCTAssertEqual(output.fullName, input.fullName)

            try app.test(.GET, "/workers/\(output.id)", afterResponse: { detail in
                XCTAssertEqual(detail.status, .ok)
            })
        })
    }

    /// Ensures that attempting to create two workers with the same employeeKey
    /// results in a conflict response from the API.
    func testDuplicateEmployeeKey() throws {
        let input = Worker.Input(employeeKey: "dup@example.com", fullName: "Jane", team: nil, role: nil)
        try app.test(.POST, "/workers", beforeRequest: { req in
            try req.content.encode(input)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created)
        })

        try app.test(.POST, "/workers", beforeRequest: { req in
            try req.content.encode(input)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .conflict)
        })
    }

    /// Validates the archive and restore workflow for a worker.
    /// The test checks that deletion returns HTTP 204 and that a subsequent
    /// restore call returns the worker with HTTP 200.
    func testArchiveAndRestore() throws {
        let input = Worker.Input(employeeKey: "arc@example.com", fullName: "Arc Hive", team: nil, role: nil)
        var workerID: UUID = UUID()
        try app.test(.POST, "/workers", beforeRequest: { req in
            try req.content.encode(input)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created)
            workerID = try res.content.decode(Worker.Output.self).id
        })

        try app.test(.DELETE, "/workers/\(workerID)", afterResponse: { res in
            XCTAssertEqual(res.status, .noContent)
        })

        try app.test(.POST, "/workers/\(workerID)/restore", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }

    /// Validates worker update operation.
    /// The test verifies that changed fields are persisted.
    func testUpdateWorker() throws {
        let input = Worker.Input(employeeKey: "update@example.com", fullName: "Old Name", team: "TeamA", role: "RoleA")
        var workerID: UUID = UUID()
        try app.test(.POST, "/workers", beforeRequest: { req in
            try req.content.encode(input)
        }, afterResponse: { res in
            workerID = try res.content.decode(Worker.Output.self).id
        })

        let update = Worker.Update(employeeKey: nil, fullName: "New Name", team: "TeamB", role: "RoleB")
        try app.test(.PUT, "/workers/\(workerID)", beforeRequest: { req in
            try req.content.encode(update)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let out = try res.content.decode(Worker.Output.self)
            XCTAssertEqual(out.fullName, "New Name")
            XCTAssertEqual(out.team, "TeamB")
            XCTAssertEqual(out.role, "RoleB")
        })
    }

    /// Ensures that listing endpoint returns created workers.
    /// The test asserts pagination headers and item count.
    func testListWorkers() throws {
        let input = Worker.Input(employeeKey: "list@example.com", fullName: "List User", team: nil, role: nil)
        try app.test(.POST, "/workers", beforeRequest: { req in
            try req.content.encode(input)
        })

        try app.test(.GET, "/workers", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: "X-Page"), "1")
            let items = try res.content.decode([Worker.Output].self)
            XCTAssertFalse(items.isEmpty)
        })
    }
}
