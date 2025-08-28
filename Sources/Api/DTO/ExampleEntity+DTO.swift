import Core
import Foundation
import Vapor

extension ExampleEntity {

	/// Input data required to create an example entity
	struct Input: Content {
		/// Example string value
		public let stringExample: String
		/// Optional integer value
		public let optionalIntegerExample: Int?
		/// Enum value provided by the client
		public let enumExample: ExampleEnum
	}

	/// Output representation of an example entity
	struct Output: Content {
		/// Example string value
		public let stringExample: String
		/// Optional integer value
		public let optionalIntegerExample: Int?
		/// Enum value
		public let enumExample: ExampleEnum
		/// Creation date
		public let createdAt: Date

		/// Initialize DTO from model
		init(exampleEntity: ExampleEntity) throws {
			self.stringExample = exampleEntity.stringExample
			self.optionalIntegerExample = exampleEntity.optionalIntegerExample
			self.enumExample = exampleEntity.enumExample
			self.createdAt = exampleEntity.createdAt!
		}
	}

}

/// Placeholder DTO used for broker events
struct ExampleEventDTO: Codable {

}
