import Foundation

/// Represents a normalized break interval
public struct NormalizedBreak {
    public let start: Date
    public let end: Date
}

/// Represents a normalized shift with associated breaks
public struct NormalizedEntry {
    public let workerName: String
    public let date: Date
    public var start: Date
    public var end: Date
    public var breaks: [NormalizedBreak]
}

/// Service that converts raw rows into normalized shifts and breaks
public struct TimesheetNormalizer {
    public init() {}

    /// Normalize raw rows from the parser applying grouping and overlap rules
    public func normalize(_ rows: [TimesheetRow]) -> [NormalizedEntry] {
        struct GroupKey: Hashable { let worker: String; let date: Date }
        var results: [NormalizedEntry] = []
        let grouped = Dictionary(grouping: rows, by: { GroupKey(worker: $0.workerName, date: $0.date) })

        for (key, groupRows) in grouped {
            let worker = key.worker
            let date = key.date
            var shifts: [NormalizedEntry] = []
            var breaks: [NormalizedBreak] = []

            for r in groupRows {
                if r.label != nil, r.shiftStart != nil, r.shiftEnd != nil {
                    let start = r.shiftStart ?? r.entry ?? r.shiftStart!
                    let end = max(r.shiftEnd ?? r.exit ?? r.shiftEnd!, r.exit ?? r.shiftEnd!)
                    shifts.append(NormalizedEntry(workerName: worker, date: date, start: start, end: end, breaks: []))
                } else if r.label == nil, let bStart = r.entry, let bEnd = r.exit {
                    breaks.append(NormalizedBreak(start: bStart, end: bEnd))
                }
            }

            // associate breaks to shifts by overlap
            for br in breaks {
                var bestIndex: Int?
                var bestOverlap: TimeInterval = 0
                for (index, shift) in shifts.enumerated() {
                    let overlap = Self.overlap(between: br, and: shift)
                    if overlap > bestOverlap {
                        bestOverlap = overlap
                        bestIndex = index
                    }
                }
                if let idx = bestIndex, bestOverlap > 0 {
                    shifts[idx].breaks.append(br)
                    if br.end > shifts[idx].end {
                        shifts[idx].end = br.end
                    }
                }
            }

            results.append(contentsOf: shifts)
        }

        return results
    }

    private static func overlap(between br: NormalizedBreak, and shift: NormalizedEntry) -> TimeInterval {
        let start = max(br.start, shift.start)
        let end = min(br.end, shift.end)
        return max(0, end.timeIntervalSince(start))
    }
}
