import Vapor

/// DTO namespace for ImportBatch endpoints
public enum ImportBatchDTO {
        /// Input payload for timesheet upload
        public struct UploadInput: Content, Validatable {
                /// Identifier of the file previously uploaded to aml.file
                public var fileID: UUID

                public static func validations(_ validations: inout Validations) {}
        }
}
