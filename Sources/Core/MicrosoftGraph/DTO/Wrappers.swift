import Vapor

/// Generic wrapper for Graph responses shaped as `{ "value": [...] }`.
struct GraphListWrapper<T: Decodable>: Decodable { let value: [T] }

/// Paged variant carrying `@odata.nextLink`.
struct GraphPagedListWrapper<T: Decodable>: Decodable {
    let value: [T]
    let nextLink: String?
    enum CodingKeys: String, CodingKey { case value; case nextLink = "@odata.nextLink" }
}

