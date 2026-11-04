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

    static func kind(for name: String) -> FileKind {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "mkv", "avi", "m4v", "webm", "wmv", "flv", "mpg", "mpeg", "3gp", "ts", "m2ts":
            return FileKind(symbol: "video.fill", color: video)
        case "zip", "rar", "7z", "gz", "tar", "bz2", "xz", "tgz", "tbz", "cab", "lz", "zst":
            return FileKind(symbol: "archivebox.fill", color: compressed)
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp", "svg", "raw", "cr2", "nef":
            return FileKind(symbol: "photo.fill", color: image)
        case "mp3", "wav", "flac", "aac", "m4a", "ogg", "wma", "ape", "aiff", "aif", "opus":
            return FileKind(symbol: "music.note", color: audio)
        case "dmg", "pkg", "app", "iso", "img", "exe", "msi", "msix", "apk", "deb", "rpm", "appimage":
            return FileKind(symbol: "opticaldisc.fill", color: app)
        default:
            return FileKind(symbol: "doc.fill", color: file)
        }
    }
}
