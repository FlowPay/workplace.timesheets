import Vapor

/// DTO namespace for ImportBatch endpoints
public enum ImportBatchDTO {
    /// Input payload for timesheet upload
    public struct UploadInput: Content, Validatable {
        public var file: File
        public var filename: String?
        public var uploadedBy: String?

        public static func validations(_ validations: inout Validations) {}
    }
}
