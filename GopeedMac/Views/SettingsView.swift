import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DownloadStore
    @Environment(\.dismiss) private var dismiss

    @State private var raw: [String: Any] = [:]
    @State private var downloadDir = ""
    @State private var maxRunning = 5
    @State private var httpConnections = 16
    @State private var userAgent = ""
    @State private var useServerCtime = false
    @State private var ftpConnections = 16
    @State private var btListenPort = 0
    @State private var seedKeep = false
    @State private var seedRatio = 0.0
    @State private var disableDht = false
    @State private var disablePex = false
    @State private var autoUpdateTrackers = true
    @State private var customTrackers = ""
    @State private var proxyEnable = false
    @State private var proxySystem = true
    @State private var proxyScheme = "http"
    @State private var proxyHost = ""
    @State private var proxyUser = ""
    @State private var proxyPassword = ""
    @State private var autoStartTasks = false
    @State private var autoDeleteMissing = false
    @State private var autoCategorize = false
    @State private var autoTorrent = false
    @State private var deleteTorrentAfter = false
    @State private var autoExtract = false
    @State private var deleteAfterExtract = false
    @State private var isLoading = true
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                Text(store.isEngineReady ? "Engine 127.0.0.1:\(GopeedEngine.shared.port)" : "Engine stopped")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceLG)
            .padding(.bottom, Theme.spaceMD)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spaceLG) {
                        section("Appearance") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Panels Opacity")
                                        .foregroundStyle(Theme.secondary)
                                    Spacer()
                                    Text("\(Int((store.panelOpacity * 100).rounded()))%")
                                        .monospacedDigit()
                                        .foregroundStyle(.white)
                                }
                                Slider(value: $store.panelOpacity, in: 0.25...0.95, step: 0.01)
                                    .tint(.white)
                                Text("Darker panels hide the wallpaper more. Lower opacity keeps more glass.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.tertiary)
                            }
                        }
                        section("General") {
                            folderRow
                            stepperRow("Max running downloads", value: $maxRunning, range: 1...32)
                            toggleRow("Resume unfinished tasks on launch", isOn: $autoStartTasks)
                            toggleRow("Remove tasks whose files are missing", isOn: $autoDeleteMissing)
                            toggleRow("Auto-categorize by file type", isOn: $autoCategorize)
                        }
                        section("HTTP") {
                            stepperRow("Connections per download", value: $httpConnections, range: 1...64)
                            labeledField("User Agent", text: $userAgent)
                            toggleRow("Use server time for created files", isOn: $useServerCtime)
                        }
                        section("BitTorrent") {
                            stepperRow("Listen port (0 = random)", value: $btListenPort, range: 0...65535)
                            toggleRow("Keep seeding after download", isOn: $seedKeep)
                            HStack {
                                Text("Seed ratio")
                                    .foregroundStyle(Theme.secondary)
                                Spacer()
                                TextField("0", value: $seedRatio, format: .number)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 72)
                            }
                            toggleRow("Disable DHT", isOn: $disableDht)
                            toggleRow("Disable PEX", isOn: $disablePex)
                            toggleRow("Auto-update tracker lists", isOn: $autoUpdateTrackers)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom trackers")
                                    .foregroundStyle(Theme.secondary)
                                TextEditor(text: $customTrackers)
                                    .font(.system(size: 12, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 88)
                                    .padding(10)
                                    .liquidGlass(cornerRadius: 12)
                            }
                        }
                        section("FTP") {
                            stepperRow("Connections", value: $ftpConnections, range: 1...64)
                        }
                        section("Proxy") {
                            toggleRow("Enable proxy", isOn: $proxyEnable)
                            toggleRow("Use system proxy", isOn: $proxySystem)
                            if proxyEnable && !proxySystem {
                                labeledField("Scheme", text: $proxyScheme)
                                labeledField("Host", text: $proxyHost)
                                labeledField("Username", text: $proxyUser)
                                SecureField("Password", text: $proxyPassword)
                                    .textFieldStyle(.plain)
                            }
                        }
                        section("Automation") {
                            toggleRow("Create a torrent task from downloaded .torrent files", isOn: $autoTorrent)
                            toggleRow("Delete .torrent after creating the BT task", isOn: $deleteTorrentAfter)
                            toggleRow("Extract archives when a download finishes", isOn: $autoExtract)
                            toggleRow("Delete archive after extraction", isOn: $deleteAfterExtract)
                        }
                    }
                    .padding(.horizontal, Theme.spaceXL)
                    .padding(.bottom, Theme.spaceMD)
                }
            }

            HStack {
                Text("Storage  ~/Library/Application Support/GopeedMac")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(CapsuleActionButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(isSaving ? "Saving…" : "Save") {
                    Task { await save() }
                }
                .buttonStyle(CapsuleActionButtonStyle(kind: .prominent))
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || isLoading)
            }
            .padding(Theme.spaceXL)
        }
        .frame(width: 680, height: 720)
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    private var folderRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Download folder")
                    .foregroundStyle(Theme.secondary)
                Text(downloadDir.isEmpty ? "Downloads" : downloadDir)
                    .lineLimit(1)
                    .foregroundStyle(.white)
            }
            Spacer()
            Button("Choose…") { pickFolder() }
                .buttonStyle(CapsuleActionButtonStyle())
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.spaceMD) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondary)
            VStack(alignment: .leading, spacing: Theme.spaceMD) {
                content()
            }
            .padding(Theme.spaceMD)
            .liquidGlass(cornerRadius: 18)
        }
        .font(.system(size: 13))
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.switch)
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.secondary)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .monospacedDigit()
                    .frame(minWidth: 36, alignment: .trailing)
            }
        }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.secondary)
                .frame(width: 110, alignment: .leading)
            TextField(title, text: text)
                .textFieldStyle(.plain)
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: downloadDir.isEmpty ? store.defaultDownloadDir : downloadDir)
        if panel.runModal() == .OK, let url = panel.url {
            downloadDir = url.path
        }
    }

    private func load() async {
        await store.loadConfig()
        raw = store.engineConfig
        downloadDir = JSONValue.string(raw["downloadDir"]) ?? store.defaultDownloadDir
        maxRunning = max(1, JSONValue.int(raw["maxRunning"]))
        autoStartTasks = JSONValue.bool(raw["autoStartTasks"])
        autoDeleteMissing = JSONValue.bool(raw["autoDeleteMissingFileTasks"])
        autoCategorize = JSONValue.bool(raw["autoCategorize"])
        let proto = raw["protocolConfig"] as? [String: Any] ?? [:]
        let http = proto["http"] as? [String: Any] ?? [:]
        httpConnections = max(1, JSONValue.int(http["connections"]))
        if httpConnections == 0 { httpConnections = 16 }
        userAgent = JSONValue.string(http["userAgent"]) ?? ""
        useServerCtime = JSONValue.bool(http["useServerCtime"])
        let ftp = proto["ftp"] as? [String: Any] ?? [:]
        ftpConnections = max(1, JSONValue.int(ftp["connections"]))
        if ftpConnections == 0 { ftpConnections = 16 }
        let bt = proto["bt"] as? [String: Any] ?? [:]
        btListenPort = JSONValue.int(bt["listenPort"])
        seedKeep = JSONValue.bool(bt["seedKeep"])
        seedRatio = JSONValue.double(bt["seedRatio"])
        disableDht = JSONValue.bool(bt["disableDht"])
        disablePex = JSONValue.bool(bt["disablePex"])
        autoUpdateTrackers = JSONValue.bool(bt["autoUpdateTrackers"], default: true)
        if let trackers = bt["customTrackers"] as? [Any] {
            customTrackers = trackers.compactMap { $0 as? String }.joined(separator: "\n")
        }
        let proxy = raw["proxy"] as? [String: Any] ?? [:]
        proxyEnable = JSONValue.bool(proxy["enable"])
        proxySystem = JSONValue.bool(proxy["system"])
        proxyScheme = JSONValue.string(proxy["scheme"]).flatMap { $0.isEmpty ? nil : $0 } ?? "http"
        proxyHost = JSONValue.string(proxy["host"]) ?? ""
        proxyUser = JSONValue.string(proxy["usr"]) ?? ""
        proxyPassword = JSONValue.string(proxy["pwd"]) ?? ""
        let torrent = raw["autoTorrent"] as? [String: Any] ?? [:]
        autoTorrent = JSONValue.bool(torrent["enable"])
        deleteTorrentAfter = JSONValue.bool(torrent["deleteAfterDownload"])
        let archive = raw["archive"] as? [String: Any] ?? [:]
        autoExtract = JSONValue.bool(archive["autoExtract"])
        deleteAfterExtract = JSONValue.bool(archive["deleteAfterExtract"])
        isLoading = false
    }

    private func save() async {
        isSaving = true
        var json = raw
        json["downloadDir"] = downloadDir
        json["maxRunning"] = maxRunning
        json["autoStartTasks"] = autoStartTasks
        json["autoDeleteMissingFileTasks"] = autoDeleteMissing
        json["autoCategorize"] = autoCategorize

        var proto = json["protocolConfig"] as? [String: Any] ?? [:]
        var http = proto["http"] as? [String: Any] ?? [:]
        http["connections"] = httpConnections
        http["userAgent"] = userAgent
        http["useServerCtime"] = useServerCtime
        proto["http"] = http
        var ftp = proto["ftp"] as? [String: Any] ?? [:]
        ftp["connections"] = ftpConnections
        proto["ftp"] = ftp
        var bt = proto["bt"] as? [String: Any] ?? [:]
        bt["listenPort"] = btListenPort
        bt["seedKeep"] = seedKeep
        bt["seedRatio"] = seedRatio
        bt["disableDht"] = disableDht
        bt["disablePex"] = disablePex
        bt["autoUpdateTrackers"] = autoUpdateTrackers
        bt["customTrackers"] = customTrackers
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        proto["bt"] = bt
        json["protocolConfig"] = proto

        var proxy = json["proxy"] as? [String: Any] ?? [:]
        proxy["enable"] = proxyEnable
        proxy["system"] = proxySystem
        proxy["scheme"] = proxyScheme
        proxy["host"] = proxyHost
        proxy["usr"] = proxyUser
        proxy["pwd"] = proxyPassword
        json["proxy"] = proxy

        var torrent = json["autoTorrent"] as? [String: Any] ?? [:]
        torrent["enable"] = autoTorrent
        torrent["deleteAfterDownload"] = deleteTorrentAfter
        json["autoTorrent"] = torrent

        var archive = json["archive"] as? [String: Any] ?? [:]
        archive["autoExtract"] = autoExtract
        archive["deleteAfterExtract"] = deleteAfterExtract
        json["archive"] = archive

        await store.saveConfig(json)
        isSaving = false
        if store.engineError == nil {
            dismiss()
        }
    }
}

private enum JSONValue {
    static func int(_ value: Any?, default fallback: Int = 0) -> Int {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String, let i = Int(s) { return i }
        return fallback
    }

    static func bool(_ value: Any?, default fallback: Bool = false) -> Bool {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        return fallback
    }

    static func double(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let i = value as? Int { return Double(i) }
        return 0
    }

    static func string(_ value: Any?) -> String? {
        value as? String
    }
}
