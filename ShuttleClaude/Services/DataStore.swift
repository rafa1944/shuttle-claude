import AppKit
import CryptoKit
import Foundation
import SwiftUI

@MainActor
final class DataStore: ObservableObject {
    @Published var providers: [Provider] = []
    @Published var settings: AppSettings = AppSettings()

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ShuttleClaude", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("shuttle_data.json")
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(ShuttleData.self, from: data)
            self.providers = decoded.providers
            self.settings = decoded.settings
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    private func save() {
        sanitizePasswords()
        let shuttleData = ShuttleData(providers: providers, settings: settings)
        do {
            let data = try JSONEncoder().encode(shuttleData)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    private func sanitizePasswords() {
        for pIdx in providers.indices {
            for prIdx in providers[pIdx].projects.indices {
                for eIdx in providers[pIdx].projects[prIdx].elements.indices {
                    if let pwd = providers[pIdx].projects[prIdx].elements[eIdx].sudoPassword,
                       pwd.hasPrefix("enc:") || pwd.hasPrefix("b64:") {
                        providers[pIdx].projects[prIdx].elements[eIdx].sudoPassword = nil
                    }
                }
            }
        }
    }

    // MARK: - Settings

    func updateTerminal(_ terminal: TerminalApp) {
        settings.terminalApp = terminal
        save()
    }

    func updateCustomTerminalPath(_ path: String?) {
        settings.customTerminalPath = path
        save()
    }

    func updateCopySudoOnConnect(_ value: Bool) {
        settings.copySudoOnConnect = value
        save()
    }

    // MARK: - Provider CRUD

    func addProvider(name: String) {
        providers.append(Provider(name: name))
        save()
    }

    func updateProvider(id: UUID, name: String) {
        guard let idx = providers.firstIndex(where: { $0.id == id }) else { return }
        providers[idx].name = name
        save()
    }

    func deleteProvider(id: UUID) {
        providers.removeAll { $0.id == id }
        save()
    }

    // MARK: - Project CRUD

    func addProject(providerID: UUID, name: String, url: String? = nil) {
        guard let idx = providers.firstIndex(where: { $0.id == providerID }) else { return }
        providers[idx].projects.append(Project(name: name, url: url))
        save()
    }

    func updateProject(providerID: UUID, projectID: UUID, name: String, url: String? = nil) {
        guard let pIdx = providers.firstIndex(where: { $0.id == providerID }),
              let prIdx = providers[pIdx].projects.firstIndex(where: { $0.id == projectID })
        else { return }
        providers[pIdx].projects[prIdx].name = name
        providers[pIdx].projects[prIdx].url = url
        save()
    }

    func deleteProject(providerID: UUID, projectID: UUID) {
        guard let pIdx = providers.firstIndex(where: { $0.id == providerID }) else { return }
        providers[pIdx].projects.removeAll { $0.id == projectID }
        save()
    }

    // MARK: - Element CRUD

    func addElement(providerID: UUID, projectID: UUID, element: Element) {
        guard let pIdx = providers.firstIndex(where: { $0.id == providerID }),
              let prIdx = providers[pIdx].projects.firstIndex(where: { $0.id == projectID })
        else { return }
        providers[pIdx].projects[prIdx].elements.append(element)
        save()
    }

    func updateElement(providerID: UUID, projectID: UUID, element: Element) {
        guard let pIdx = providers.firstIndex(where: { $0.id == providerID }),
              let prIdx = providers[pIdx].projects.firstIndex(where: { $0.id == projectID }),
              let eIdx = providers[pIdx].projects[prIdx].elements.firstIndex(where: { $0.id == element.id })
        else { return }
        providers[pIdx].projects[prIdx].elements[eIdx] = element
        save()
    }

    func deleteElement(providerID: UUID, projectID: UUID, elementID: UUID) {
        guard let pIdx = providers.firstIndex(where: { $0.id == providerID }),
              let prIdx = providers[pIdx].projects.firstIndex(where: { $0.id == projectID })
        else { return }
        providers[pIdx].projects[prIdx].elements.removeAll { $0.id == elementID }
        save()
    }

    // MARK: - Merge

    private func mergeProviders(from imported: [Provider]) {
        for importedProvider in imported {
            if let idx = providers.firstIndex(where: { $0.id == importedProvider.id }) {
                mergeProjects(into: &providers[idx], from: importedProvider)
            } else {
                providers.append(importedProvider)
            }
        }
    }

    private func mergeProjects(into provider: inout Provider, from imported: Provider) {
        for importedProject in imported.projects {
            if let idx = provider.projects.firstIndex(where: { $0.id == importedProject.id }) {
                mergeElements(into: &provider.projects[idx], from: importedProject)
            } else {
                provider.projects.append(importedProject)
            }
        }
    }

    private func mergeElements(into project: inout Project, from imported: Project) {
        for importedElement in imported.elements {
            if !project.elements.contains(where: { $0.id == importedElement.id }) {
                project.elements.append(importedElement)
            }
        }
    }

    // MARK: - Export / Import

    private func showAlert(_ message: String, informative: String = "", style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = message
        alert.informativeText = informative
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func askPassword(title: String, message: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancelar")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "Contraseña"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = input.stringValue
        return value.isEmpty ? nil : value
    }

    private func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        // SHA256(password + salt) as a simple KDF
        var hashData = Data(password.utf8)
        hashData.append(salt)
        let hash = SHA256.hash(data: hashData)
        return SymmetricKey(data: hash)
    }

    private func encrypt(_ plaintext: String, key: SymmetricKey) throws -> String {
        let data = Data(plaintext.utf8)
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined!.base64EncodedString()
    }

    private func decrypt(_ cipherB64: String, key: SymmetricKey) throws -> String {
        guard let combined = Data(base64Encoded: cipherB64) else {
            throw NSError(domain: "DataStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid base64"])
        }
        let box = try AES.GCM.SealedBox(combined: combined)
        let decrypted = try AES.GCM.open(box, using: key)
        return String(data: decrypted, encoding: .utf8) ?? ""
    }

    func exportData() {
        let password = askPassword(
            title: "Exportar datos",
            message: "Introduce una contraseña para cifrar las claves sudo en la exportación."
        )

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "shuttle_data.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var salt: Data?
        var key: SymmetricKey?
        if let password {
            let s = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
            salt = s
            key = deriveKey(from: password, salt: s)
        }

        var exportProviders = providers
        for pIdx in exportProviders.indices {
            for prIdx in exportProviders[pIdx].projects.indices {
                for eIdx in exportProviders[pIdx].projects[prIdx].elements.indices {
                    if let pwd = exportProviders[pIdx].projects[prIdx].elements[eIdx].sudoPassword,
                       !pwd.isEmpty, let key {
                        if let encrypted = try? encrypt(pwd, key: key) {
                            exportProviders[pIdx].projects[prIdx].elements[eIdx].sudoPassword = "enc:\(encrypted)"
                        }
                    }
                }
            }
        }

        var shuttleData = ShuttleData(providers: exportProviders, settings: settings)
        shuttleData.exportSalt = salt?.base64EncodedString()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(shuttleData)
            try data.write(to: url, options: .atomic)
            showAlert("Exportación completada", informative: "Los datos se han exportado correctamente.")
        } catch {
            showAlert("Error al exportar", informative: error.localizedDescription, style: .critical)
        }
    }

    func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            var decoded = try JSONDecoder().decode(ShuttleData.self, from: data)

            let hasEncrypted = decoded.providers.flatMap(\.projects).flatMap(\.elements)
                .contains { $0.sudoPassword?.hasPrefix("enc:") == true }

            var key: SymmetricKey?
            if hasEncrypted {
                guard let saltB64 = decoded.exportSalt,
                      let salt = Data(base64Encoded: saltB64) else {
                    showAlert("Error al importar", informative: "El archivo no contiene la información de cifrado necesaria.", style: .critical)
                    return
                }
                guard let password = askPassword(
                    title: "Importar datos",
                    message: "Introduce la contraseña usada al exportar para descifrar las claves sudo."
                ) else { return }
                key = deriveKey(from: password, salt: salt)
            }

            for pIdx in decoded.providers.indices {
                for prIdx in decoded.providers[pIdx].projects.indices {
                    for eIdx in decoded.providers[pIdx].projects[prIdx].elements.indices {
                        if let pwd = decoded.providers[pIdx].projects[prIdx].elements[eIdx].sudoPassword,
                           pwd.hasPrefix("enc:"), let key {
                            let cipher = String(pwd.dropFirst(4))
                            do {
                                let plain = try decrypt(cipher, key: key)
                                decoded.providers[pIdx].projects[prIdx].elements[eIdx].sudoPassword = plain
                            } catch {
                                showAlert("Contraseña incorrecta", informative: "No se pudieron descifrar las claves sudo. Verifica la contraseña e inténtalo de nuevo.", style: .critical)
                                return
                            }
                        }
                    }
                }
            }

            let alert = NSAlert()
            alert.messageText = "¿Cómo quieres importar los datos?"
            alert.informativeText = "Reemplazar sustituye todos los datos actuales. Fusionar añade los proveedores, proyectos y elementos nuevos manteniendo los existentes."
            alert.addButton(withTitle: "Reemplazar")
            alert.addButton(withTitle: "Fusionar")
            alert.addButton(withTitle: "Cancelar")
            let response = alert.runModal()

            if response == .alertThirdButtonReturn { return }

            if response == .alertFirstButtonReturn {
                self.providers = decoded.providers
                self.settings = decoded.settings
            } else {
                mergeProviders(from: decoded.providers)
                self.settings = decoded.settings
            }

            save()
            showAlert("Importación completada", informative: "Los datos se han importado correctamente.")
        } catch {
            showAlert("Error al importar", informative: "El archivo no es válido: \(error.localizedDescription)", style: .critical)
        }
    }
}
