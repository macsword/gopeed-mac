# GDM

**GDM (Gopeed Download Manager)** is a native macOS fork of [Gopeed](https://github.com/GopeedLab/gopeed).

This project keeps the Gopeed download engine (HTTP, BitTorrent, magnet, ed2k) and replaces the Flutter desktop UI with a SwiftUI Mac app.

Upstream: [GopeedLab/gopeed](https://github.com/GopeedLab/gopeed) (GPL-3.0)

## What is different

- Native SwiftUI app for macOS 26, branded GDM
- Liquid Glass window that samples the desktop wallpaper
- Same Gopeed REST engine, hosted locally over HTTP (`NativeMode=false`)
- Settings, inspector, sorting, and file-type colors in the Mac UI

The Gopeed Flutter app, mobile clients, and web UI are not part of this repo. Clone upstream if you need those.

## Requirements

- macOS 26+
- Xcode 26 / 15+
- Go 1.25+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```bash
git clone https://github.com/macsword/gopeed-mac.git
cd gopeed-mac
git clone --depth 1 https://github.com/GopeedLab/gopeed.git engine/gopeed
./Scripts/build-engine.sh
xcodegen generate
xcodebuild -scheme GopeedMac -destination 'platform=macOS' -configuration Release ONLY_ACTIVE_ARCH=YES ARCHS=arm64 build
```

Or open `GopeedMac.xcodeproj` in Xcode after `xcodegen generate`.

`engine/gopeed` is the upstream clone (gitignored). `engine/host` is the small CGO wrapper that starts Gopeed’s REST server.

## License

[GPL-3.0](LICENSE), same as Gopeed, because this app links `libgopeed`.
