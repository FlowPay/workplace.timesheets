import Vapor

/// Client responsible for retrieving files from the aml.file service.
/// Implementations should download the binary content associated with a
/// previously uploaded file identified by `UUID`.
public protocol FileAdapterProtocol {
	/// Fetches the file content for the given identifier.
	/// - Parameters:
	///   - id: Unique identifier of the file on aml.file.
	///   - client: HTTP client used to perform the request.
	/// - Returns: Raw data of the remote file.
	func fetch(id: UUID, client: Client) async throws -> Data
}

/// Live HTTP implementation calling the external aml.file service.
public struct FileAdapter: FileAdapterProtocol {
	/// Base URL of the aml.file service
	private let baseURL: String

	/// Creates a new client with the given base URL.
	public init(baseURL: String) {
		self.baseURL = baseURL
	}

	/// Performs an HTTP GET on `/files/{id}` and follows redirects to obtain the file data.
	public func fetch(id: UUID, client: Client) async throws -> Data {
		// Initial request to the aml.file service. According to the
		// service's OpenAPI specification, this endpoint issues a 303
		// redirect to the remote storage location of the file.
		let uri = URI(string: "\(baseURL)/files/\(id.uuidString)")
		let response = try await client.get(uri)

		// If a redirect is returned, follow it to download the binary content.
		if response.status == .seeOther,
			let location = response.headers.first(name: .location)
		{
			let redirected = try await client.get(URI(string: location))
			guard redirected.status == .ok, let buffer = redirected.body else {
				throw Abort(.notFound, reason: "File content not found at redirected URL")
			}
			return Data(buffer: buffer)
		}

		// Some environments may return the file directly without redirecting.
		guard response.status == .ok, let buffer = response.body else {
			throw Abort(.notFound, reason: "File not found on file service")
		}
		return Data(buffer: buffer)
	}
}

extension Application {
	/// Storage key for the aml.file client instance
	fileprivate struct AmlFileClientKey: StorageKey {
		typealias Value = FileAdapterProtocol
	}

	/// Accessor to the configured aml.file client.
	public var fileAdapter: FileAdapterProtocol {
		get {
			guard let client = self.storage[AmlFileClientKey.self] else {
				fatalError("AmlFileClient not configured. Register a client in configure.swift or tests.")
			}
			return client
		}
		set { self.storage[AmlFileClientKey.self] = newValue }
	}
}

extension Request {
	/// Convenience accessor exposing the configured `AmlFileClient` from a request context.
	/// Controllers can use this to interact with the file service without referencing the application object.
	public var fileAdapter: FileAdapterProtocol {
		self.application.fileAdapter
	}
}
