import AppKit
import SwiftUI

struct AddDownloadSheet: View {
    @EnvironmentObject private var store: DownloadStore
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var saveFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    @State private var isSubmitting = false
    @State private var didApplyDefaults = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceLG) {
            Text("Add Download")
                .font(.system(size: 20, weight: .semibold))
            TextField("https://, magnet:, or ed2k://", text: $urlText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(Theme.spaceMD)
                .lineLimit(3...6)
                .liquidGlass(cornerRadius: 12)
            HStack {
                Text(saveFolder?.path ?? "Downloads")
                    .lineLimit(1)
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Button("Choose Folder…") { pickFolder() }
                    .buttonStyle(CapsuleActionButtonStyle())
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(CapsuleActionButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Download") {
                    Task { await submit() }
                }
                .buttonStyle(CapsuleActionButtonStyle(kind: .prominent))
                .keyboardShortcut(.defaultAction)
                .disabled(URL(string: urlText) == nil || isSubmitting)
            }
        }
        .padding(Theme.spaceXL)
        .frame(width: 560)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didApplyDefaults else { return }
            didApplyDefaults = true
            let dir = store.defaultDownloadDir
            if !dir.isEmpty {
                saveFolder = URL(fileURLWithPath: dir)
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = saveFolder
        if panel.runModal() == .OK {
            saveFolder = panel.url
        }
    }

    private func submit() async {
        isSubmitting = true
        await store.add(url: urlText.trimmingCharacters(in: .whitespacesAndNewlines), path: saveFolder?.path)
        isSubmitting = false
        dismiss()
    }
}
