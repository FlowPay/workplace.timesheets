import Vapor

/// Abstraction for objects capable of supplying Microsoft Graph OAuth tokens.
public protocol MicrosoftGraphTokenProvider {
    /// Returns a bearer token that can be used to authenticate against Graph.
    func accessToken(client: Client) async throws -> String
}

/// Token provider performing OAuth2 client credential flow against Azure AD.
/// The token is cached in memory until shortly before its expiry time.
public actor ClientCredentialsTokenProvider: MicrosoftGraphTokenProvider {
    private let tenantId: String
    private let clientId: String
    private let clientSecret: String
    private let scope: String

    private var cachedToken: String?
    private var expiry: Date?

    /// Creates a new provider using client credentials.
    public init(tenantId: String, clientId: String, clientSecret: String, scope: String = "https://graph.microsoft.com/.default") {
        self.tenantId = tenantId
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scope = scope
    }

    /// Performs the token request if necessary and returns a valid access token.
    public func accessToken(client: Client) async throws -> String {
        if let token = cachedToken, let expiry = expiry, expiry > Date() {
            return token
        }

        let uri = URI(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/x-www-form-urlencoded")
        struct TokenRequest: Content {
            let client_id: String
            let client_secret: String
            let grant_type: String = "client_credentials"
            let scope: String
        }
        let request = TokenRequest(client_id: clientId, client_secret: clientSecret, scope: scope)
        let response = try await client.post(uri, headers: headers) { req in
            try req.content.encode(request, as: .urlEncodedForm)
        }
        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Token request failed with status \(response.status.code)")
        }
        struct TokenResponse: Content { let access_token: String; let expires_in: Int }
        let payload = try response.content.decode(TokenResponse.self)
        cachedToken = payload.access_token
        expiry = Date().addingTimeInterval(TimeInterval(payload.expires_in - 60))
        return payload.access_token
    }
}
