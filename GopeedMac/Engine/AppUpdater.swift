import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppUpdater: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = AppUpdater()

    @Published var isChecking = false
    @Published var updateAvailable: GitHubRelease?
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var showUpdateSheet = false
    @Published var showUpToDateAlert = false

    private var downloadTask: URLSessionDownloadTask?
    private var downloadContinuation: CheckedContinuation<URL, Error>?

    struct GitHubRelease: Decodable, Identifiable {
        let id: Int
        let tagName: String
        let name: String?
        let body: String?
        let htmlUrl: String
        let publishedAt: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case id
            case tagName = "tag_name"
            case name
            case body
            case htmlUrl = "html_url"
            case publishedAt = "published_at"
            case assets
        }

        struct Asset: Decodable, Identifiable {
            let id: Int
            let name: String
            let browserDownloadUrl: String
            let size: Int64

            enum CodingKeys: String, CodingKey {
                case id
                case name
                case browserDownloadUrl = "browser_download_url"
                case size
            }
        }

        var versionString: String {
            tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        }

        var macAsset: Asset? {
            // First check for a zip file mentioning gdm / gopeed / mac
            if let asset = assets.first(where: {
                $0.name.hasSuffix(".zip") &&
                ($0.name.localizedCaseInsensitiveContains("gdm") ||
                 $0.name.localizedCaseInsensitiveContains("gopeed") ||
                 $0.name.localizedCaseInsensitiveContains("mac"))
            }) {
                return asset
            }
            // Any zip asset
            if let asset = assets.first(where: { $0.name.hasSuffix(".zip") }) {
                return asset
            }
            // Any dmg asset
            if let asset = assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                return asset
            }
            return nil
        }
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private let repoOwner = "macsword"
    private let repoName = "gopeed-mac"

    func checkForUpdates(userInitiated: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil

        let endpoint = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: endpoint) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("GDM-Updater/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                isChecking = false
                return
            }

            if http.statusCode == 404 {
                isChecking = false
                if userInitiated {
                    showUpToDateAlert = true
                }
                return
            }

            guard http.statusCode == 200 else {
                isChecking = false
                if userInitiated {
                    errorMessage = "Server returned code \(http.statusCode)"
                }
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            isChecking = false

            if isNewerVersion(release.versionString, than: currentVersion) {
                updateAvailable = release
                showUpdateSheet = true
            } else if userInitiated {
                showUpToDateAlert = true
            }
        } catch {
            isChecking = false
            if userInitiated {
                errorMessage = error.localizedDescription
            }
        }
    }

    func isNewerVersion(_ newVer: String, than currentVer: String) -> Bool {
        let v1 = newVer.split(separator: ".").compactMap { Int($0) }
        let v2 = currentVer.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(v1.count, v2.count)

        for i in 0..<maxCount {
            let p1 = i < v1.count ? v1[i] : 0
            let p2 = i < v2.count ? v2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }

    func installUpdate() async {
        guard let release = updateAvailable else { return }
        guard let asset = release.macAsset, let downloadURL = URL(string: asset.browserDownloadUrl) else {
            if let pageURL = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(pageURL)
            }
            return
        }

        isDownloading = true
        downloadProgress = 0
        statusMessage = "Downloading \(asset.name)…"
        errorMessage = nil

        do {
            let downloadedZip = try await downloadFile(from: downloadURL)
            statusMessage = "Extracting update…"

            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("GDMUpdate-\(UUID().uuidString)")
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzipProcess.arguments = ["-xk", downloadedZip.path, tempDir.path]
            try unzipProcess.run()
            unzipProcess.waitUntilExit()

            guard unzipProcess.terminationStatus == 0 else {
                throw NSError(domain: "GDMUpdate", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract update archive."])
            }

            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
                throw NSError(domain: "GDMUpdate", code: 2, userInfo: [NSLocalizedDescriptionKey: "No application found in update archive."])
            }

            statusMessage = "Relaunching GDM…"
            let currentAppURL = Bundle.main.bundleURL
            let targetPath = (currentAppURL.path.contains("/Applications/") || currentAppURL.lastPathComponent == "GDM.app")
                ? currentAppURL.path
                : "/Applications/GDM.app"

            let pid = ProcessInfo.processInfo.processIdentifier
            let relaunchScript = """
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            rm -rf "\(targetPath)"
            /usr/bin/ditto "\(appURL.path)" "\(targetPath)"
            /usr/bin/touch "\(targetPath)"
            open "\(targetPath)"
            rm -rf "\(tempDir.path)" "\(downloadedZip.path)"
            """

            let relaunchProcess = Process()
            relaunchProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
            relaunchProcess.arguments = ["-c", relaunchScript]
            try relaunchProcess.run()

            NSApp.terminate(nil)
        } catch {
            isDownloading = false
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    private func downloadFile(from url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.downloadContinuation = continuation
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            self.downloadTask = task
            task.resume()
        }
    }

    // MARK: - URLSessionDownloadDelegate
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempDestination = FileManager.default.temporaryDirectory.appendingPathComponent("GDMUpdate-\(UUID().uuidString).zip")
        do {
            try FileManager.default.moveItem(at: location, to: tempDestination)
            Task { @MainActor in
                self.downloadContinuation?.resume(returning: tempDestination)
                self.downloadContinuation = nil
            }
        } catch {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.downloadProgress = progress
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }
}
