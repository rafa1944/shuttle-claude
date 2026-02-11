import SwiftUI

struct ProviderEditorView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let providerID: UUID?
    @State private var name: String = ""

    var isEditing: Bool { providerID != nil }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Provider" : "New Provider")
                .font(.headline)

            TextField("Provider Name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save" : "Add") {
                    if let id = providerID {
                        store.updateProvider(id: id, name: name)
                    } else {
                        store.addProvider(name: name)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            if let id = providerID,
               let provider = store.providers.first(where: { $0.id == id }) {
                name = provider.name
            }
        }
    }
}
