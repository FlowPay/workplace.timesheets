import Foundation

/// Represents a raw row parsed from the Teams Shifts export.
public struct TimesheetRow: Decodable {
        public let workerName: String
        public let date: Date
        public let label: String?
        public let entry: Date?
        public let exit: Date?
        public let shiftStart: Date?
        public let shiftEnd: Date?
        public let unpaidMinutes: Int?
        public let breakStart: Date?
        public let breakEnd: Date?
}

/// Utility responsible for parsing the Teams Shifts export using Python's openpyxl.
public struct TimesheetParser {
	/// Default initializer
	public init() {}
        /// Parses the provided Excel file and returns raw rows.
        /// - Parameter path: Path to the XLSX file on disk.
        public func parse(at path: String) throws -> [TimesheetRow] {
                let script = """
import json, openpyxl, sys
wb = openpyxl.load_workbook(sys.argv[1], data_only=True)
ws = wb.active
rows = []
for r in ws.iter_rows(min_row=2, values_only=True):
    date = r[1]
    name = r[3]
    label = r[4]
    entry = r[5]
    exit = r[6]
    sstart = r[7]
    send = r[8]
    unpaid = r[9]
    bstart = r[15]
    bend = r[16]
    if date is None or name is None:
        continue
    row = {
        'workerName': name,
        'date': date.isoformat()
    }
    if label:
        row['label'] = label
    if entry:
        row['entry'] = entry.isoformat()
    if exit:
        row['exit'] = exit.isoformat()
    if sstart:
        row['shiftStart'] = sstart.isoformat()
    if send:
        row['shiftEnd'] = send.isoformat()
    if unpaid is not None:
        row['unpaidMinutes'] = int(unpaid)
    if bstart and bend:
        row['breakStart'] = bstart.isoformat()
        row['breakEnd'] = bend.isoformat()
    rows.append(row)
print(json.dumps(rows))
"""
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
		process.arguments = ["-c", script, path]
                // Inherit the current environment to allow Python to locate installed modules
                // such as `openpyxl` without overriding `PYTHONPATH`.
                process.environment = ProcessInfo.processInfo.environment
		let pipe = Pipe()
		process.standardOutput = pipe
		try process.run()
		process.waitUntilExit()
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try decoder.decode([TimesheetRow].self, from: data)
	}
}
