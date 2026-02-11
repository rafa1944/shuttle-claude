import SwiftUI

struct ProjectEditorView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let providerID: UUID
    let projectID: UUID?
    @State private var name: String = ""
    @State private var url: String = ""

    var isEditing: Bool { projectID != nil }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Project" : "New Project")
                .font(.headline)

            Form {
                TextField("Project Name", text: $name)
                TextField("URL (optional)", text: $url)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save" : "Add") {
                    let trimmedURL = url.trimmingCharacters(in: .whitespaces)
                    let finalURL: String? = trimmedURL.isEmpty ? nil : trimmedURL
                    if let id = projectID {
                        store.updateProject(providerID: providerID, projectID: id, name: name, url: finalURL)
                    } else {
                        store.addProject(providerID: providerID, name: name, url: finalURL)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            if let id = projectID,
               let provider = store.providers.first(where: { $0.id == providerID }),
               let project = provider.projects.first(where: { $0.id == id }) {
                name = project.name
                url = project.url ?? ""
            }
        }
    }
}
