import AppKit
import SwiftUI

struct UpdateView: View {
    @ObservedObject var updater: AppUpdater
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 48, height: 48)
                    .background(Theme.accent.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Update Available")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    if let release = updater.updateAvailable {
                        HStack(spacing: 6) {
                            Text("v\(updater.currentVersion)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.tertiary)
                            Text("v\(release.versionString)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.success)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, Theme.spaceLG)
            .padding(.top, Theme.spaceLG)
            .padding(.bottom, Theme.spaceMD)

            Divider()
                .overlay(Theme.hairline)

            // Release Notes
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let release = updater.updateAvailable {
                        if let name = release.name, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        if let body = release.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(body)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.secondary)
                                .textSelection(.enabled)
                        } else {
                            Text("No release notes provided.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.tertiary)
                        }
                    }
                }
                .padding(Theme.spaceLG)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 260)
            .background(Color.black.opacity(0.2))

            Divider()
                .overlay(Theme.hairline)

            // Progress / Error / Actions
            VStack(spacing: 12) {
                if let error = updater.errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if updater.isDownloading {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(updater.statusMessage ?? "Downloading…")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.secondary)
                            Spacer()
                            Text("\(Int((updater.downloadProgress * 100).rounded()))%")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                        ProgressView(value: updater.downloadProgress, total: 1.0)
                            .tint(Theme.accent)
                    }
                }

                HStack(spacing: 12) {
                    if let urlString = updater.updateAvailable?.htmlUrl, let url = URL(string: urlString) {
                        Button("View on GitHub") {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                    }

                    Spacer()

                    Button("Later") {
                        dismiss()
                    }
                    .buttonStyle(CapsuleActionButtonStyle(kind: .regular))
                    .disabled(updater.isDownloading)

                    if updater.updateAvailable?.macAsset != nil {
                        Button {
                            Task { await updater.installUpdate() }
                        } label: {
                            HStack(spacing: 6) {
                                if updater.isDownloading {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                }
                                Text(updater.isDownloading ? "Updating…" : "Update Now")
                            }
                        }
                        .buttonStyle(CapsuleActionButtonStyle(kind: .prominent))
                        .disabled(updater.isDownloading)
                    } else {
                        Button("Download on GitHub") {
                            if let urlString = updater.updateAvailable?.htmlUrl, let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                            dismiss()
                        }
                        .buttonStyle(CapsuleActionButtonStyle(kind: .prominent))
                    }
                }
            }
            .padding(Theme.spaceLG)
        }
        .frame(width: 480)
        .paneGlass(cornerRadius: 20)
    }
}
