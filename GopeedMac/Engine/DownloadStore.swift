import AppKit
import Foundation
import SwiftUI

@MainActor
final class DownloadStore: ObservableObject {
    @Published var tasks: [DownloadTask] = []
    @Published var filter: SidebarFilter = .all {
        didSet { reconcileSelection() }
    }
    @Published var typeFilter: FileKind.Category = .all {
        didSet { reconcileSelection() }
    }
    @Published var selection: DownloadTask.ID?
    @Published var search = "" {
        didSet { reconcileSelection() }
    }
    @Published var engineError: String?
    @Published var isEngineReady = false
    @Published var showingAdd = false
    @Published var showingSettings = false
    @Published var speedHistory: [String: [SpeedSample]] = [:]
    @Published var statsByID: [String: TaskStats] = [:]
    @Published var connectionsDraft: Int = 16
    @Published var sort: TaskSort = .added
    @Published var sortAscending = false
    @Published var inspectorCollapsed = false
    @Published var engineConfig: [String: Any] = [:]
    @Published var defaultDownloadDir: String = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
    @Published var defaultConnections: Int = 16
    @Published var panelOpacity: Double = UserDefaults.standard.object(forKey: "gdm.panelOpacity") as? Double ?? 0.78 {
        didSet {
            UserDefaults.standard.set(panelOpacity, forKey: "gdm.panelOpacity")
        }
    }

    private let client = GopeedClient()
    private var pollTask: Task<Void, Never>?
    private var lastSnapshot: [TaskSnapshot] = []
    private var lastStatsAt = Date.distantPast
    private var lastStatsID: String?

    var visibleTasks: [DownloadTask] {
        var list = tasks.filter { task in
            filter.matches(task)
                && typeFilter.matches(task)
                && (search.isEmpty || task.displayName.localizedCaseInsensitiveContains(search))
        }
        list.sort { lhs, rhs in
            let ordered: Bool
            switch sort {
            case .added:
                ordered = (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
            case .name:
                ordered = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            case .size:
                ordered = lhs.totalSize < rhs.totalSize
            case .progress:
                ordered = lhs.fraction < rhs.fraction
            case .status:
                ordered = lhs.status.rawValue < rhs.status.rawValue
            case .speed:
                ordered = lhs.speed < rhs.speed
            }
            return sortAscending ? ordered : !ordered
        }
        return list
    }

    var selectedTask: DownloadTask? {
        if let selection, let match = tasks.first(where: { $0.id == selection }) {
            return match
        }
        return visibleTasks.first
    }

    func start() {
        do {
            try GopeedEngine.shared.start()
            isEngineReady = true
            engineError = nil
            startPolling()
            Task { await loadConfig() }
        } catch {
            engineError = error.localizedDescription
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        GopeedEngine.shared.stop()
        isEngineReady = false
    }

    func refresh() async {
        guard isEngineReady else { return }
        do {
            let list = try await client.listTasks()
            let snapshot = list.map(TaskSnapshot.init)
            if snapshot != lastSnapshot {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    tasks = list
                }
                lastSnapshot = snapshot
            }
            reconcileSelection()
            if let selected = selectedTask {
                if selected.status == .running {
                    recordSpeed(for: selected)
                }
                let needsStats = selected.id != lastStatsID
                    || (selected.status == .running && Date().timeIntervalSince(lastStatsAt) > 1.5)
                if needsStats {
                    lastStatsAt = Date()
                    lastStatsID = selected.id
                    if let stats = try? await client.stats(id: selected.id), statsByID[selected.id] != stats {
                        statsByID[selected.id] = stats
                    }
                    if connectionsDraft != selected.connections {
                        connectionsDraft = selected.connections
                    }
                }
            }
            engineError = nil
        } catch {
            engineError = error.localizedDescription
        }
    }

    func add(url: String, path: String?) async {
        await addLinks([url], path: path)
    }

    func pasteFromClipboard() async {
        let links = DownloadLinkParser.clipboardLinks()
        guard !links.isEmpty else {
            engineError = "Clipboard has no download link."
            return
        }
        await addLinks(links, path: defaultDownloadDir.isEmpty ? nil : defaultDownloadDir)
    }

    func addLinks(_ raw: [String], path: String? = nil) async {
        let links = raw.flatMap { DownloadLinkParser.links(from: $0) }
        guard !links.isEmpty else {
            engineError = "No download link found."
            return
        }
        let destination = path ?? (defaultDownloadDir.isEmpty ? nil : defaultDownloadDir)
        var lastID: String?
        for link in links {
            do {
                lastID = try await client.createTask(url: link, path: destination, connections: defaultConnections)
            } catch {
                engineError = error.localizedDescription
            }
        }
        await refresh()
        if let lastID {
            selection = lastID
        }
    }

    func loadConfig() async {
        guard isEngineReady else { return }
        do {
            let json = try await client.getConfig()
            applyConfig(json)
            engineError = nil
        } catch {
            engineError = error.localizedDescription
        }
    }

    func saveConfig(_ json: [String: Any]) async {
        do {
            try await client.putConfig(json)
            applyConfig(json)
            engineError = nil
        } catch {
            engineError = error.localizedDescription
        }
    }

    private func applyConfig(_ json: [String: Any]) {
        engineConfig = json
        if let dir = json["downloadDir"] as? String, !dir.isEmpty {
            defaultDownloadDir = dir
        }
        if let proto = json["protocolConfig"] as? [String: Any],
           let http = proto["http"] as? [String: Any] {
            let connections: Int
            if let i = http["connections"] as? Int {
                connections = i
            } else if let n = http["connections"] as? NSNumber {
                connections = n.intValue
            } else {
                connections = 0
            }
            if connections > 0 {
                defaultConnections = connections
            }
        }
    }

    func pause(_ task: DownloadTask) async {
        await run { try await client.pause(id: task.id) }
    }

    func resume(_ task: DownloadTask) async {
        await run { try await client.resume(id: task.id) }
    }

    func delete(_ task: DownloadTask, removeFiles: Bool) async {
        await run { try await client.delete(id: task.id, removeFiles: removeFiles) }
        if selection == task.id {
            selection = nil
        }
    }

    func setConnections(_ value: Int, for task: DownloadTask) async {
        connectionsDraft = value
        await run { try await client.patchConnections(id: task.id, connections: value) }
    }

    func reveal(_ task: DownloadTask) {
        if let file = task.fileURL, FileManager.default.fileExists(atPath: file.path) {
            NSWorkspace.shared.activateFileViewerSelecting([file])
            return
        }
        if let path = task.meta?.opts?.path {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    func openURL(_ task: DownloadTask) {
        guard let raw = task.meta?.req?.url, let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }

    private func recordSpeed(for task: DownloadTask) {
        let now = Date()
        let cutoff = now.addingTimeInterval(-60)
        var samples = speedHistory[task.id] ?? []
        if let last = samples.last, now.timeIntervalSince(last.date) < 0.7, last.bytesPerSecond == task.speed {
            return
        }
        samples.append(SpeedSample(date: now, bytesPerSecond: task.speed))
        samples.removeAll { $0.date < cutoff }
        speedHistory[task.id] = samples
    }

    private func run(_ work: () async throws -> Void) async {
        do {
            try await work()
            await refresh()
        } catch {
            engineError = error.localizedDescription
        }
    }

    private func reconcileSelection() {
        if let selection, visibleTasks.contains(where: { $0.id == selection }) {
            return
        }
        selection = visibleTasks.first?.id
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let running = self?.tasks.contains { $0.status == .running || $0.status == .wait } == true
                try? await Task.sleep(for: .milliseconds(running ? 900 : 2500))
            }
        }
    }
}

private struct TaskSnapshot: Equatable {
    let id: String
    let status: TaskStatus
    let downloaded: Int64
    let speed: Int64
    let total: Int64
    let used: Int64

    init(_ task: DownloadTask) {
        id = task.id
        status = task.status
        downloaded = task.downloaded
        speed = task.speed
        total = task.totalSize
        used = task.progress?.used ?? 0
    }
}
