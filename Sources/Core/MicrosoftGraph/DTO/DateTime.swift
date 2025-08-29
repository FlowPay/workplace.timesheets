import Vapor

/// Microsoft Graph DateTimeTimeZone shape
public struct GraphDateTimeTimeZone: Content, Sendable {
	public let dateTime: Date
	public let timeZone: String?

	var date: Date { dateTime }  //FIXME: remove this!

	public init(dateTime: Date, timeZone: String? = nil) {
		self.dateTime = dateTime
		self.timeZone = timeZone
	}

	// /// Parses the `dateTime` ISO-8601 string into Date.
	// public var date: Date {
	// 	let isoFS = ISO8601DateFormatter()
	// 	isoFS.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
	// 	if let d = isoFS.date(from: dateTime) { return d }
	// 	let iso = ISO8601DateFormatter()
	// 	iso.formatOptions = [.withInternetDateTime]
	// 	return iso.date(from: dateTime) ?? Date(timeIntervalSince1970: 0)
	// }

	// // Flexible decoding: accepts either a plain ISO string or an object { dateTime, timeZone }
	// public init(from decoder: Decoder) throws {
	// 	let container = try decoder.singleValueContainer()
	// 	if let str = try? container.decode(String.self) {
	// 		self.dateTime = str
	// 		self.timeZone = nil
	// 		return
	// 	}
	// 	let obj = try decoder.container(keyedBy: CodingKeys.self)
	// 	self.dateTime = try obj.decode(String.self, forKey: .dateTime)
	// 	self.timeZone = try? obj.decode(String.self, forKey: .timeZone)
	// }

	// enum CodingKeys: String, CodingKey { case dateTime, timeZone }
}
