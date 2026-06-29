import Foundation
import Observation

enum LogLevel: String {
    case info    = "ℹ️"
    case success = "✅"
    case warning = "⚠️"
    case error   = "❌"
    case debug   = "🔧"
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: timestamp)
    }

    var exportLine: String {
        "[\(formattedTime)] \(level.rawValue) \(message)"
    }
}

@Observable
final class AppLogger {

    static let shared = AppLogger()
    private init() {}

    private(set) var entries: [LogEntry] = []
    private let maxEntries = 500

    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)
        DispatchQueue.main.async {
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
        // Также в системный лог
        print("[\(level.rawValue)] \(message)")
    }

    func clear() {
        entries.removeAll()
    }

    func exportText() -> String {
        let header = "=== Xasu DPI Bypass — Log Export ===\nDate: \(Date())\nEntries: \(entries.count)\n\n"
        let body = entries.map(\.exportLine).joined(separator: "\n")
        return header + body
    }
}
