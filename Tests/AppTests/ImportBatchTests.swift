import XCTVapor
import Vapor

@testable import Api
@testable import App
@testable import Core

/// Tests for ImportBatch endpoints
final class ImportBatchTests: BaseTestCase {
    /// Ensures that uploading a timesheet returns a batch in queued status
    /// and that the batch can be retrieved via GET endpoint.
    /// The assertions verify HTTP codes and initial counter values.
    func testUploadAndRetrieveBatch() throws {
        let fileData = Data("dummy".utf8)
        let boundary = "Boundary-\(UUID().uuidString)"
        var buffer = ByteBuffer()
        buffer.writeString("--\(boundary)\r\n")
        buffer.writeString("Content-Disposition: form-data; name=\"file\"; filename=\"test.xlsx\"\r\n")
        buffer.writeString("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n")
        buffer.writeBytes(fileData)
        buffer.writeString("\r\n--\(boundary)--\r\n")

        try app.test(.POST, "/imports/timesheet", beforeRequest: { req in
            req.headers.contentType = HTTPMediaType(type: "multipart", subType: "form-data", parameters: ["boundary": boundary])
            req.body = .init(buffer: buffer)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .accepted)
            let batch = try res.content.decode(ImportBatch.self)
            XCTAssertEqual(batch.status, .queued)
            XCTAssertEqual(batch.rowsTotal, 0)

            try app.test(.GET, "/imports/\(batch.id!)", afterResponse: { getRes in
                XCTAssertEqual(getRes.status, .ok)
            })
        })
    }
}
