import Foundation

enum GopeedEngineError: LocalizedError {
    case alreadyRunning
    case startFailed(String)
    case notRunning
    case missingLibrary

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "The download engine is already running."
        case .startFailed(let message):
            return message
        case .notRunning:
            return "The download engine is not running."
        case .missingLibrary:
            return "libgopeed.dylib is missing from the app bundle."
        }
    }
}

final class GopeedEngine {
    static let shared = GopeedEngine()

    private(set) var port: Int = 0
    private(set) var token: String = ""
    private var started = false
    private let lock = NSLock()

    var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        if started { return }

        token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GopeedMac", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? support.appendingPathComponent("Downloads", isDirectory: true)

        let config: [String: Any] = [
            "network": "tcp",
            "address": "127.0.0.1:0",
            "storage": "bolt",
            "storageDir": support.path,
            "apiToken": token,
            "downloadConfig": [
                "downloadDir": downloads.path,
                "maxRunning": 5,
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: config)
        guard let json = String(data: data, encoding: .utf8) else {
            throw GopeedEngineError.startFailed("Could not encode engine config.")
        }

        let result = json.withCString { pointer in
            Start(UnsafeMutablePointer(mutating: pointer))
        }

        if let errorPointer = result.r1 {
            let message = String(cString: errorPointer)
            FreeCString(errorPointer)
            throw GopeedEngineError.startFailed(message)
        }

        guard result.r0 > 0 else {
            throw GopeedEngineError.startFailed("Engine started without an API port.")
        }

        port = Int(result.r0)
        started = true
        NSLog("Gopeed engine listening on 127.0.0.1:%d", port)
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard started else { return }
        Stop()
        started = false
        port = 0
    }
}
