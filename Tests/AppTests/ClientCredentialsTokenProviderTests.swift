import XCTVapor
import Atomics
@testable import Core

/// Tests ensuring the client credentials provider requests and caches tokens.
final class ClientCredentialsTokenProviderTests: XCTestCase {
    /// Verifies that the provider calls the token endpoint and caches the result.
    func testFetchesAndCachesToken() async throws {
        let provider = ClientCredentialsTokenProvider(tenantId: "tenant", clientId: "id", clientSecret: "secret")
        let loop = EmbeddedEventLoop()
        let calls = ManagedAtomic(0)
        struct RecordingClient: Client {
            let eventLoop: EventLoop
            let handler: @Sendable (ClientRequest) -> EventLoopFuture<ClientResponse>
            func delegating(to eventLoop: EventLoop) -> Client { self }
            func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> { handler(request) }
            func logging(to logger: Logger) -> Client { self }
            func allocating(to byteBufferAllocator: ByteBufferAllocator) -> Client { self }
        }

        let client = RecordingClient(eventLoop: loop) { request in
            _ = calls.wrappingIncrement(ordering: .relaxed)
            XCTAssertEqual(request.method, .POST)
            XCTAssertEqual(request.url.string, "https://login.microsoftonline.com/tenant/oauth2/v2.0/token")
            var buffer = request.body ?? ByteBuffer()
            let body = buffer.readString(length: buffer.readableBytes) ?? ""
            XCTAssertTrue(body.contains("client_id=id"))
            XCTAssertTrue(body.contains("client_secret=secret"))
            XCTAssertTrue(body.contains("scope=https%3A%2F%2Fgraph.microsoft.com%2F.default"))
            var res = ClientResponse(status: .ok, headers: ["Content-Type": "application/json"])
            res.body = .init(string: "{\"access_token\":\"abc\",\"expires_in\":3600}")
            return loop.makeSucceededFuture(res)
        }

        let token1 = try await provider.accessToken(client: client)
        let token2 = try await provider.accessToken(client: client)
        XCTAssertEqual(token1, "abc")
        XCTAssertEqual(token2, "abc")
        XCTAssertEqual(calls.load(ordering: .relaxed), 1)
    }
}
