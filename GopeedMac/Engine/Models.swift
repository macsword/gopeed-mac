import Foundation
import SwiftUI

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case ready
    case running
    case pause
    case wait
    case error
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ready: return "Ready"
        case .running: return "Downloading"
        case .pause: return "Paused"
        case .wait: return "Queued"
        case .error: return "Failed"
        case .done: return "Completed"
        }
    }
}

struct APIEnvelope<T: Decodable>: Decodable {
    let code: Int
    let msg: String?
    let data: T?
}

struct APIVoid: Decodable {}

struct DownloadTask: Identifiable, Decodable, Hashable {
    let id: String
    let name: String?
    let protocolName: String?
    let status: TaskStatus
    let uploading: Bool?
    let progress: TaskProgress?
    let meta: TaskMeta?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, status, uploading, progress, meta, createdAt, updatedAt
        case protocolName = "protocol"
    }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let url = meta?.req?.url, let last = URL(string: url)?.lastPathComponent, !last.isEmpty {
            return last
        }
        return "Untitled download"
    }

    var downloaded: Int64 { progress?.downloaded ?? 0 }
    var speed: Int64 { progress?.speed ?? 0 }
    var totalSize: Int64 { meta?.res?.size ?? 0 }
    var elapsedNanos: Int64 { progress?.used ?? 0 }

    var fraction: Double {
        guard totalSize > 0 else { return status == .done ? 1 : 0 }
        return min(1, Double(downloaded) / Double(totalSize))
    }

    var percentText: String {
        String(format: "%.1f%%", fraction * 100)
    }

    var remaining: TimeInterval? {
        guard status == .running, speed > 0, totalSize > downloaded else { return nil }
        return Double(totalSize - downloaded) / Double(speed)
    }

    var elapsed: TimeInterval {
        Double(elapsedNanos) / 1_000_000_000
    }

    var averageSpeed: Int64 {
        let seconds = elapsed
        guard seconds > 0 else { return speed }
        return Int64(Double(downloaded) / seconds)
    }

    var fileURL: URL? {
        guard let path = meta?.opts?.path else { return nil }
        return URL(fileURLWithPath: path).appendingPathComponent(displayName)
    }

    var connections: Int {
        meta?.opts?.extra?.connections ?? 16
    }
}

struct TaskProgress: Decodable, Hashable {
    let used: Int64?
    let speed: Int64?
    let downloaded: Int64?
    let uploadSpeed: Int64?
    let uploaded: Int64?
}

struct TaskMeta: Decodable, Hashable {
    let req: TaskRequest?
    let res: TaskResource?
    let opts: TaskOptions?
}

struct TaskRequest: Decodable, Hashable {
    let url: String?
}

struct TaskResource: Decodable, Hashable {
    let name: String?
    let size: Int64?
    let range: Bool?
}

struct TaskOptions: Decodable, Hashable {
    let name: String?
    let path: String?
    let extra: TaskExtra?
}

struct TaskExtra: Decodable, Hashable {
    let connections: Int?
}

struct TaskStats: Decodable, Hashable {
    let connections: [StatConnection]?
}

struct StatConnection: Decodable, Hashable {
    let downloaded: Int64?
    let total: Int64?
    let completed: Bool?
    let failed: Bool?
}

struct CreateTaskBody: Encodable {
    struct Request: Encodable {
        let url: String
    }

    struct Options: Encodable {
        struct Extra: Encodable {
            let connections: Int
        }

        let path: String?
        let name: String?
        let extra: Extra?
    }

    let req: Request
    let opts: Options?
}

struct PatchTaskBody: Encodable {
    struct Options: Encodable {
        struct Extra: Encodable {
            let connections: Int
        }
        let extra: Extra
    }
    let opts: Options
}

enum SidebarFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .done: return "Done"
        }
    }

    func matches(_ task: DownloadTask) -> Bool {
        switch self {
        case .all: return true
        case .active: return task.status != .done
        case .done: return task.status == .done
        }
    }
}

enum TaskSort: String, CaseIterable, Identifiable {
    case added
    case name
    case size
    case progress
    case status
    case speed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .added: return "Date Added"
        case .name: return "Name"
        case .size: return "Size"
        case .progress: return "Progress"
        case .status: return "Status"
        case .speed: return "Speed"
        }
    }
}

struct SpeedSample: Hashable {
    let date: Date
    let bytesPerSecond: Int64
}

enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesUnit = true
        return formatter
    }()

    static func string(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }

    static func speed(_ bytesPerSecond: Int64) -> String {
        "\(string(bytesPerSecond))/s"
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func remainingShort(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)h \(minutes)m remaining" }
        if minutes > 0 { return "\(minutes)m \(seconds)s remaining" }
        return "\(seconds)s remaining"
    }
}
