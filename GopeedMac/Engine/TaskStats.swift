import Foundation

/// Response of `GET /api/v1/tasks/{id}/stats`.
///
/// Gopeed wraps protocol-specific stats in `fetcher.Stats`:
/// `{"snapshot": {...}, "runtime": {...}}`. For HTTP tasks the snapshot is
/// `{"connections": [{"downloaded", "total", "completed", "failed", "retryTimes"}]}`
/// (see `pkg/protocol/http/model.go` upstream). Other protocols (BitTorrent,
/// ed2k) use different snapshot shapes, so `connections` is optional and an
/// unknown snapshot simply decodes to `nil`.
struct TaskStats: Decodable, Hashable {
    let connections: [StatConnection]?

    init(connections: [StatConnection]?) {
        self.connections = connections
    }

    private enum CodingKeys: String, CodingKey {
        case snapshot
        case connections
    }

    private struct Snapshot: Decodable {
        let connections: [StatConnection]?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let snapshot = try? container.decodeIfPresent(Snapshot.self, forKey: .snapshot) {
            connections = snapshot.connections
        } else {
            // Older engines returned the HTTP snapshot without the wrapper.
            connections = try? container.decodeIfPresent([StatConnection].self, forKey: .connections)
        }
    }
}

/// One HTTP connection reported by the engine.
///
/// `total` is NOT the byte length of a fixed file range: the engine reports
/// `resourceSize / currentConnectionCount` (rounded up) for every connection so
/// clients can compare each connection's contribution. Connections can be added
/// or rebalanced (work stealing) while a download runs, so `downloaded` may
/// exceed `total`. Treat `fraction` as an estimate.
struct StatConnection: Decodable, Hashable {
    let downloaded: Int64?
    let total: Int64?
    let completed: Bool?
    let failed: Bool?
    let retryTimes: Int?

    enum State: Equatable {
        case active
        case completed
        case failed
    }

    var state: State {
        if failed == true { return .failed }
        if completed == true { return .completed }
        return .active
    }

    /// Share of the nominal per-connection total, clamped to 0...1.
    /// `nil` when the engine does not know the resource size (total == 0).
    var fraction: Double? {
        if completed == true { return 1 }
        guard let total, total > 0 else { return nil }
        return min(1, max(0, Double(downloaded ?? 0) / Double(total)))
    }
}

/// Detects tasks that newly finished between two polls.
///
/// The first observation only records a baseline, so downloads that were
/// already complete when the app launched never produce a notification.
/// Each task id is reported at most once per completion; a task that leaves
/// the done state (e.g. restarted) can be reported again later.
struct CompletionTracker {
    private var baselineTaken = false
    private var doneIDs: Set<String> = []

    init() {}

    /// - Parameter tasks: current `(id, isDone)` pairs from the latest poll.
    /// - Returns: ids that transitioned to done since the previous call.
    mutating func newlyCompleted(_ tasks: [(id: String, isDone: Bool)]) -> [String] {
        let currentDone = Set(tasks.filter(\.isDone).map(\.id))
        defer {
            doneIDs = currentDone
            baselineTaken = true
        }
        guard baselineTaken else { return [] }
        return tasks.filter { $0.isDone && !doneIDs.contains($0.id) }.map(\.id)
    }
}
