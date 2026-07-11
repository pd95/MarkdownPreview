import SwiftUI

#if os(macOS)
struct FolderAccessSettingsView: View {
    @EnvironmentObject private var localDocumentAccess: LocalDocumentAccess

    var body: some View {
        Form {
            Section("Files & Folders") {
                Text("MarkLens uses these folders to load linked documents and local images.")
                    .foregroundStyle(.secondary)

                if localDocumentAccess.authorizedFolders.isEmpty {
                    ContentUnavailableView(
                        "No Authorized Folders",
                        systemImage: "folder.badge.questionmark",
                        description: Text("Folder access is requested when a local link or image needs it.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    List(localDocumentAccess.authorizedFolders, id: \.self) { folder in
                        HStack {
                            Label(folder.path, systemImage: "folder")
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("Forget", systemImage: "trash", role: .destructive) {
                                localDocumentAccess.revoke(folder: folder)
                            }
                            .labelStyle(.iconOnly)
                            .help("Forget access to \(folder.lastPathComponent)")
                        }
                    }
                    .frame(minHeight: 140)

                    Button("Forget All Folder Access", role: .destructive) {
                        localDocumentAccess.revokeAll()
                    }
                }
            }

            Section {
                Text("Documents previously opened in MarkLens may remain individually accessible through macOS after folder access is removed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 360)
        .padding()
    }
}

#Preview {
    FolderAccessSettingsView()
        .environmentObject(LocalDocumentAccess())
}
#endif
