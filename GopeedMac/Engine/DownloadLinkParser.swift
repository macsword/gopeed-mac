import AppKit
import Foundation
import UniformTypeIdentifiers

enum DownloadLinkParser {
    static func links(from string: String) -> [String] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var found: [String] = []
        let chunks = trimmed.components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: .whitespaces) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for chunk in chunks {
            if isDownloadLink(chunk) {
                found.append(chunk)
            }
        }

        if found.isEmpty, isDownloadLink(trimmed) {
            found.append(trimmed)
        }

        if found.isEmpty, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            detector.enumerateMatches(in: trimmed, options: [], range: range) { match, _, _ in
                guard let match, let range = Range(match.range, in: trimmed) else { return }
                let value = String(trimmed[range])
                if isDownloadLink(value) { found.append(value) }
            }
        }

        var seen = Set<String>()
        return found.filter { seen.insert($0).inserted }
    }

    static func isDownloadLink(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        let lower = value.lowercased()
        if lower.hasPrefix("magnet:") { return true }
        if lower.hasPrefix("ed2k://") { return true }
        if lower.hasPrefix("ftp://") || lower.hasPrefix("ftps://") { return true }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return true }
        if lower.hasPrefix("file://"), lower.hasSuffix(".torrent") { return true }
        if lower.hasSuffix(".torrent"), (value as NSString).isAbsolutePath { return true }
        return false
    }

    static func expanded(_ raw: String) -> [String] {
        if isDownloadLink(raw) { return [raw] }
        let url: URL?
        if raw.hasPrefix("file://") {
            url = URL(string: raw)
        } else if (raw as NSString).isAbsolutePath {
            url = URL(fileURLWithPath: raw)
        } else {
            url = nil
        }
        guard let url, url.isFileURL else { return [] }
        let path = url.path
        let lower = path.lowercased()
        if lower.hasSuffix(".torrent") { return [url.absoluteString] }
        if lower.hasSuffix(".webloc") {
            if let parsed = weblocURL(at: path) { return [parsed] }
        }
        if lower.hasSuffix(".url") || lower.hasSuffix(".txt") {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return links(from: text)
            }
        }
        return []
    }

    static func weblocURL(at path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let url = plist["URL"] as? String,
              isDownloadLink(url) else { return nil }
        return url
    }

    static func clipboardLinks() -> [String] {
        links(from: NSPasteboard.general)
    }

    static func links(from pasteboard: NSPasteboard) -> [String] {
        var collected: [String] = []

        if let url = NSURL(from: pasteboard) as URL? {
            collected.append(normalized(url))
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self, NSString.self], options: nil) {
            for object in urls {
                if let url = object as? URL {
                    collected.append(normalized(url))
                } else if let string = object as? String {
                    collected.append(contentsOf: links(from: string))
                }
            }
        }
        if let files = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            collected.append(contentsOf: files.map { URL(fileURLWithPath: $0).absoluteString })
        }
        let types: [NSPasteboard.PasteboardType] = [
            .string, .URL, .fileURL,
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.utf8-plain-text"),
            NSPasteboard.PasteboardType("public.plain-text"),
            NSPasteboard.PasteboardType("Apple URL pasteboard type"),
            NSPasteboard.PasteboardType("text/uri-list")
        ]
        for type in types {
            if let string = pasteboard.string(forType: type) {
                collected.append(contentsOf: links(from: string))
            }
            if let data = pasteboard.data(forType: type),
               let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) {
                collected.append(contentsOf: links(from: string.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))))
            }
        }
        if let items = pasteboard.pasteboardItems {
            for item in items {
                for type in item.types {
                    if let string = item.string(forType: type) {
                        collected.append(contentsOf: links(from: string))
                    }
                }
            }
        }

        var seen = Set<String>()
        return collected
            .flatMap { expanded($0) }
            .filter { isDownloadLink($0) && seen.insert($0).inserted }
    }

    static func normalized(_ url: URL) -> String {
        url.absoluteString
    }
}
