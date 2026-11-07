import Foundation

enum GopeedClientError: LocalizedError {
    case engine(String)
    case http(Int, String)
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .engine(let message), .http(_, let message), .decode(let message):
            return message
        }
    }
}

final class GopeedClient {
    private let engine: GopeedEngine
    private let session: URLSession
    private let decoder: JSONDecoder

    init(engine: GopeedEngine = .shared) {
        self.engine = engine
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: raw) { return date }
            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            if let date = basic.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(raw)")
        }
    }

    func listTasks() async throws -> [DownloadTask] {
        try await get("/api/v1/tasks")
    }

    func createTask(url: String, path: String?, connections: Int) async throws -> String {
        let body = CreateTaskBody(
            req: .init(url: url),
            opts: .init(path: path, name: nil, extra: .init(connections: connections))
        )
        return try await post("/api/v1/tasks", body: body)
    }

    /// Returns `nil` when the engine has no stats for the task yet (`data: null`).
    func stats(id: String) async throws -> TaskStats? {
        let (data, status) = try await raw("/api/v1/tasks/\(id)/stats", method: "GET", body: nil, query: [:])
        do {
            let envelope = try decoder.decode(APIEnvelope<TaskStats>.self, from: data)
            if envelope.code != 0 {
                throw GopeedClientError.http(status, envelope.msg ?? "Engine error \(envelope.code)")
            }
            return envelope.data
        } catch let error as GopeedClientError {
            throw error
        } catch {
            throw GopeedClientError.decode(error.localizedDescription)
        }
    }

    func patchConnections(id: String, connections: Int) async throws {
        try await sendVoid(
            "/api/v1/tasks/\(id)",
            method: "PATCH",
            body: try JSONEncoder().encode(PatchTaskBody(opts: .init(extra: .init(connections: connections))))
        )
    }

    func pause(id: String) async throws {
        try await putVoid("/api/v1/tasks/\(id)/pause")
    }

    func resume(id: String) async throws {
        try await putVoid("/api/v1/tasks/\(id)/continue")
    }

    func delete(id: String, removeFiles: Bool) async throws {
        try await deleteVoid("/api/v1/tasks/\(id)", query: ["force": removeFiles ? "true" : "false"])
    }

    func getConfig() async throws -> [String: Any] {
        let (data, _) = try await raw("/api/v1/config", method: "GET", body: nil, query: [:])
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GopeedClientError.decode("Invalid config response.")
        }
        let code = root["code"] as? Int ?? -1
        if code != 0 {
            throw GopeedClientError.http(code, root["msg"] as? String ?? "Engine error")
        }
        return root["data"] as? [String: Any] ?? [:]
    }

    func putConfig(_ json: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: json)
        try await sendVoid("/api/v1/config", method: "PUT", body: body)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(path, method: "GET", body: nil as Data?)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await send(path, method: "POST", body: data)
    }

    private func putVoid(_ path: String) async throws {
        try await sendVoid(path, method: "PUT")
    }

    private func deleteVoid(_ path: String, query: [String: String]) async throws {
        try await sendVoid(path, method: "DELETE", query: query)
    }

    private func sendVoid(_ path: String, method: String, query: [String: String] = [:], body: Data? = nil) async throws {
        let (data, status) = try await raw(path, method: method, body: body, query: query)
        do {
            let envelope = try decoder.decode(APIEnvelope<APIVoid>.self, from: data)
            if envelope.code != 0 {
                throw GopeedClientError.http(status, envelope.msg ?? "Engine error \(envelope.code)")
            }
        } catch let error as GopeedClientError {
            throw error
        } catch {
            throw GopeedClientError.decode(error.localizedDescription)
        }
    }

    private func send<T: Decodable>(_ path: String, method: String, body: Data?, query: [String: String] = [:]) async throws -> T {
        let (data, status) = try await raw(path, method: method, body: body, query: query)
        do {
            let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
            if envelope.code != 0 {
                throw GopeedClientError.http(status, envelope.msg ?? "Engine error \(envelope.code)")
            }
            guard let value = envelope.data else {
                throw GopeedClientError.decode("Missing data in engine response.")
            }
            return value
        } catch let error as GopeedClientError {
            throw error
        } catch {
            throw GopeedClientError.decode(error.localizedDescription)
        }
    }

    private func raw(_ path: String, method: String, body: Data?, query: [String: String]) async throws -> (Data, Int) {
        guard let url = URL(string: engine.baseURL.absoluteString + path) else {
            throw GopeedClientError.engine("Invalid engine URL.")
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let resolved = components.url else {
            throw GopeedClientError.engine("Invalid engine URL.")
        }

        var request = URLRequest(url: resolved)
        request.httpMethod = method
        request.setValue(engine.token, forHTTPHeaderField: "X-Api-Token")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }
}
