import SwiftUI
import AppKit

struct ElementEditorView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let providerID: UUID
    let projectID: UUID
    let elementID: UUID?

    @State private var name: String = ""
    @State private var user: String = ""
    @State private var host: String = ""
    @State private var ip: String = ""
    @State private var portString: String = "22"
    @State private var portError: String?
    @State private var sudoPassword: String = ""
    @State private var showSudoPassword: Bool = false
    @State private var copiedSudo: Bool = false
    @State private var notes: String = ""

    var isEditing: Bool { elementID != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !user.trimmingCharacters(in: .whitespaces).isEmpty &&
        !ip.trimmingCharacters(in: .whitespaces).isEmpty &&
        validPort != nil
    }

    private var validPort: Int? {
        guard let port = Int(portString), (1...65535).contains(port) else { return nil }
        return port
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Element" : "New Element")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                TextField("User", text: $user)
                TextField("Host", text: $host)
                TextField("IP", text: $ip)
                TextField("Port", text: $portString)
                    .onChange(of: portString) { newValue in
                        if let port = Int(newValue), (1...65535).contains(port) {
                            portError = nil
                        } else if !newValue.isEmpty {
                            portError = "Port must be 1–65535"
                        }
                    }

                if let portError = portError {
                    Text(portError)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                HStack {
                    if showSudoPassword {
                        TextField("Sudo password", text: $sudoPassword)
                    } else {
                        SecureField("Sudo password", text: $sudoPassword)
                    }

                    Button {
                        showSudoPassword.toggle()
                    } label: {
                        Image(systemName: showSudoPassword ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(showSudoPassword ? "Hide password" : "Show password")

                    if !sudoPassword.isEmpty {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(sudoPassword, forType: .string)
                            copiedSudo = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedSudo = false
                            }
                        } label: {
                            Image(systemName: copiedSudo ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy to clipboard")
                    }
                }

                TextEditor(text: $notes)
                    .font(.body)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Notes")
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 6)
                                .allowsHitTesting(false)
                        }
                    }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save" : "Add") {
                    guard let port = validPort else { return }
                    let trimmedSudo = sudoPassword.trimmingCharacters(in: .whitespaces)
                    let element = Element(
                        id: elementID ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespaces),
                        user: user.trimmingCharacters(in: .whitespaces),
                        host: host.trimmingCharacters(in: .whitespaces),
                        ip: ip.trimmingCharacters(in: .whitespaces),
                        port: port,
                        sudoPassword: trimmedSudo.isEmpty ? nil : trimmedSudo,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    if isEditing {
                        store.updateElement(providerID: providerID, projectID: projectID, element: element)
                    } else {
                        store.addElement(providerID: providerID, projectID: projectID, element: element)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 480)
        .onAppear {
            if let eID = elementID,
               let provider = store.providers.first(where: { $0.id == providerID }),
               let project = provider.projects.first(where: { $0.id == projectID }),
               let element = project.elements.first(where: { $0.id == eID }) {
                name = element.name
                user = element.user
                host = element.host
                ip = element.ip
                portString = "\(element.port)"
                sudoPassword = element.sudoPassword ?? ""
                notes = element.notes ?? ""
            }
        }
    }
}
