import XCTVapor
import NIOCore

@testable import Core

/// Tests verifying MicrosoftGraphClient HTTP request construction.
final class MicrosoftGraphClientTests: XCTestCase {
    /// Ensures the Authorization header is added and the correct path is called.
    func testAuthorizationHeader() async throws {
        struct StaticTokenProvider: MicrosoftGraphTokenProvider {
            func accessToken(client: Client) async throws -> String { "token123" }
        }
        let graph = MicrosoftGraphClient(baseURL: "https://graph.example", tokenProvider: StaticTokenProvider())
        let exp = expectation(description: "request")
        let loop = EmbeddedEventLoop()

        struct RecordingClient: Client {
            let eventLoop: EventLoop
            let handler: @Sendable (ClientRequest) -> EventLoopFuture<ClientResponse>
            func delegating(to eventLoop: EventLoop) -> Client { self }
            func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> { handler(request) }
            func logging(to logger: Logger) -> Client { self }
            func allocating(to byteBufferAllocator: ByteBufferAllocator) -> Client { self }
        }

        let client = RecordingClient(eventLoop: loop) { request in
            XCTAssertEqual(request.url.string, "https://graph.example/users")
            XCTAssertEqual(request.headers.first(name: .authorization), "Bearer token123")
            exp.fulfill()
            var res = ClientResponse(status: .ok, headers: ["Content-Type": "application/json"])
            res.body = .init(string: "{\"value\":[]}")
            return loop.makeSucceededFuture(res)
        }

        _ = try await graph.listUsers(client: client)
        await waitForExpectations(timeout: 1.0)
    }
}
