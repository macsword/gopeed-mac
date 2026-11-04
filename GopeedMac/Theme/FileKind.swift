import Foundation
import SwiftUI

struct FileKind {
    let symbol: String
    let color: Color

    static let video = Color(red: 0.62, green: 0.32, blue: 0.95)
    static let compressed = Color(red: 0.98, green: 0.52, blue: 0.14)
    static let image = Color(red: 0.20, green: 0.78, blue: 0.40)
    static let audio = Color(red: 0.89, green: 0.10, blue: 0.13)
    static let file = Color(red: 0.98, green: 0.80, blue: 0.18)
    static let app = Color(red: 0.18, green: 0.48, blue: 0.98)

    enum Category: String, CaseIterable, Identifiable {
        case all, video, compressed, image, audio, file, app

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .video: return "Video"
            case .compressed: return "Zip"
            case .image: return "Image"
            case .audio: return "Audio"
            case .file: return "File"
            case .app: return "Apps"
            }
        }

        var symbol: String {
            switch self {
            case .all: return "square.grid.2x2.fill"
            case .video: return "video.fill"
            case .compressed: return "archivebox.fill"
            case .image: return "photo.fill"
            case .audio: return "music.note"
            case .file: return "doc.fill"
            case .app: return "opticaldisc.fill"
            }
        }

        var color: Color {
            switch self {
            case .all: return .white
            case .video: return FileKind.video
            case .compressed: return FileKind.compressed
            case .image: return FileKind.image
            case .audio: return FileKind.audio
            case .file: return FileKind.file
            case .app: return FileKind.app
            }
        }

        var usesDarkLabel: Bool {
            switch self {
            case .all, .compressed, .image, .file: return true
            case .video, .audio, .app: return false
            }
        }

        func matches(_ task: DownloadTask) -> Bool {
            self == .all || FileKind.category(for: task.displayName) == self
        }
    }

    static func category(for name: String) -> Category {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "mkv", "avi", "m4v", "webm", "wmv", "flv", "mpg", "mpeg", "3gp", "ts", "m2ts":
            return .video
        case "zip", "rar", "7z", "gz", "tar", "bz2", "xz", "tgz", "tbz", "cab", "lz", "zst":
            return .compressed
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp", "svg", "raw", "cr2", "nef":
            return .image
        case "mp3", "wav", "flac", "aac", "m4a", "ogg", "wma", "ape", "aiff", "aif", "opus":
            return .audio
        case "dmg", "pkg", "app", "iso", "img", "exe", "msi", "msix", "apk", "deb", "rpm", "appimage":
            return .app
        default:
            return .file
        }
    }

    static func kind(for name: String) -> FileKind {
        let category = category(for: name)
        return FileKind(symbol: category.symbol, color: category.color)
    }
}
