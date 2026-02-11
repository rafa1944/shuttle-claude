import SwiftUI
import AppKit

/// Wraps an optional editing ID so `.sheet(item:)` can distinguish create vs edit.
private struct EditorConfig: Identifiable {
    let id = UUID()
    let editingID: UUID?
}

struct DataManagementView: View {
    @EnvironmentObject private var store: DataStore

    @State private var selectedProviderID: UUID?
    @State private var selectedProjectID: UUID?
    @State private var selectedElementID: UUID?

    @State private var providerEditorConfig: EditorConfig?
    @State private var projectEditorConfig: EditorConfig?
    @State private var elementEditorConfig: EditorConfig?

    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var selectedProvider: Provider? {
        store.providers.first { $0.id == selectedProviderID }
    }

    private var selectedProject: Project? {
        selectedProvider?.projects.first { $0.id == selectedProjectID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _ in
                        searchSelectedIndex = 0
                    }
                if isSearching {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)

            Divider()

            if isSearching {
                searchResultsView
            } else {
                HSplitView {
                    providerColumn
                    projectColumn
                    elementColumn
                }
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Search Results

    private struct FilteredElement: Identifiable {
        let id: UUID
        let providerName: String
        let providerID: UUID
        let projectName: String
        let projectID: UUID
        let projectURL: String?
        let element: Element

        init(provider: Provider, project: Project, element: Element) {
            self.id = element.id
            self.providerName = provider.name
            self.providerID = provider.id
            self.projectName = project.name
            self.projectID = project.id
            self.projectURL = project.url
            self.element = element
        }
    }

    private var filteredElements: [FilteredElement] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }

        var results: [FilteredElement] = []
        for provider in store.providers {
            for project in provider.projects {
                let projectMatches = project.name.lowercased().contains(query)
                    || (project.url?.lowercased().contains(query) ?? false)
                let providerMatches = provider.name.lowercased().contains(query)

                for element in project.elements {
                    let elementMatches = element.name.lowercased().contains(query)
                        || element.host.lowercased().contains(query)
                        || element.ip.lowercased().contains(query)
                        || element.user.lowercased().contains(query)
                        || (element.notes?.lowercased().contains(query) ?? false)

                    if providerMatches || projectMatches || elementMatches {
                        results.append(FilteredElement(provider: provider, project: project, element: element))
                    }
                }
            }
        }
        return results
    }

    @State private var searchSelectedIndex: Int = 0
    @State private var searchEventMonitor: Any?
    @State private var searchElementEditorConfig: EditorConfig?

    private var searchResultsView: some View {
        VStack(spacing: 0) {
            let results = filteredElements
            if results.isEmpty {
                Spacer()
                Text("No results")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            Button {
                                editSearchResult(item)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.element.name)
                                            .fontWeight(.medium)
                                        Text("\(item.providerName) › \(item.projectName)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(item.element.user)@\(item.element.ip)\(!item.element.host.isEmpty ? " (\(item.element.host))" : ""):\(item.element.port)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let url = item.projectURL, !url.isEmpty {
                                            Text(url)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .underline()
                                                .onTapGesture {
                                                    if let link = URL(string: url) {
                                                        NSWorkspace.shared.open(link)
                                                    }
                                                }
                                        }
                                        if let notes = item.element.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    if item.element.sudoPassword != nil {
                                        Button {
                                            if let pwd = item.element.sudoPassword {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(pwd, forType: .string)
                                            }
                                        } label: {
                                            Image(systemName: "key")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Copy sudo password")
                                    }
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(index == searchSelectedIndex ? Color.accentColor.opacity(0.25) : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(index)
                            .contextMenu {
                                Button("Edit…") {
                                    editSearchResult(item)
                                }
                            }
                        }
                    }
                    .onChange(of: searchSelectedIndex) { newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .onAppear { startSearchKeyMonitor() }
        .onDisappear { stopSearchKeyMonitor() }
    }

    private func editSearchResult(_ item: FilteredElement) {
        searchText = ""
        selectedProviderID = item.providerID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedProjectID = item.projectID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedElementID = item.element.id
                elementEditorConfig = EditorConfig(editingID: item.element.id)
            }
        }
    }

    private func startSearchKeyMonitor() {
        searchEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isSearching else { return event }
            let count = filteredElements.count
            guard count > 0 else { return event }

            switch event.keyCode {
            case 125: // Arrow down
                searchSelectedIndex = min(searchSelectedIndex + 1, count - 1)
                return nil
            case 126: // Arrow up
                searchSelectedIndex = max(searchSelectedIndex - 1, 0)
                return nil
            case 36: // Enter
                let results = filteredElements
                if searchSelectedIndex < results.count {
                    editSearchResult(results[searchSelectedIndex])
                }
                return nil
            default:
                return event
            }
        }
    }

    private func stopSearchKeyMonitor() {
        if let monitor = searchEventMonitor {
            NSEvent.removeMonitor(monitor)
            searchEventMonitor = nil
        }
    }

    // MARK: - Provider Column

    private var providerColumn: some View {
        VStack(spacing: 0) {
            Text("Providers")
                .font(.headline)
                .padding(8)

            Divider()

            List(store.providers, selection: $selectedProviderID) { provider in
                Text(provider.name)
                    .tag(provider.id)
                    .contextMenu {
                        Button("Edit…") {
                            providerEditorConfig = EditorConfig(editingID: provider.id)
                        }
                        Button("Delete", role: .destructive) {
                            if selectedProviderID == provider.id {
                                selectedProviderID = nil
                                selectedProjectID = nil
                                selectedElementID = nil
                            }
                            store.deleteProvider(id: provider.id)
                        }
                    }
            }
            .onChange(of: selectedProviderID) { _ in
                selectedProjectID = nil
                selectedElementID = nil
            }

            Divider()

            HStack {
                Button(action: {
                    providerEditorConfig = EditorConfig(editingID: nil)
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: {
                    guard let id = selectedProviderID else { return }
                    selectedProviderID = nil
                    selectedProjectID = nil
                    selectedElementID = nil
                    store.deleteProvider(id: id)
                }) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedProviderID == nil)
            }
            .padding(6)
        }
        .frame(minWidth: 180)
        .sheet(item: $providerEditorConfig) { config in
            ProviderEditorView(providerID: config.editingID)
                .environmentObject(store)
        }
    }

    // MARK: - Project Column

    private var projectColumn: some View {
        VStack(spacing: 0) {
            Text("Projects")
                .font(.headline)
                .padding(8)

            Divider()

            if let provider = selectedProvider {
                List(provider.projects, selection: $selectedProjectID) { project in
                    VStack(alignment: .leading) {
                        Text(project.name)
                        if let url = project.url, !url.isEmpty {
                            Text(url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .tag(project.id)
                        .contextMenu {
                            Button("Edit…") {
                                projectEditorConfig = EditorConfig(editingID: project.id)
                            }
                            Button("Delete", role: .destructive) {
                                if selectedProjectID == project.id {
                                    selectedProjectID = nil
                                    selectedElementID = nil
                                }
                                store.deleteProject(providerID: provider.id, projectID: project.id)
                            }
                        }
                }
                .onChange(of: selectedProjectID) { _ in
                    selectedElementID = nil
                }
            } else {
                Spacer()
                Text("Select a provider")
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()

            HStack {
                Button(action: {
                    projectEditorConfig = EditorConfig(editingID: nil)
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedProviderID == nil)

                Spacer()

                Button(action: {
                    guard let provID = selectedProviderID, let projID = selectedProjectID else { return }
                    selectedProjectID = nil
                    selectedElementID = nil
                    store.deleteProject(providerID: provID, projectID: projID)
                }) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedProjectID == nil)
            }
            .padding(6)
        }
        .frame(minWidth: 180)
        .sheet(item: $projectEditorConfig) { config in
            if let provID = selectedProviderID {
                ProjectEditorView(providerID: provID, projectID: config.editingID)
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Element Column

    private var elementColumn: some View {
        VStack(spacing: 0) {
            Text("Elements")
                .font(.headline)
                .padding(8)

            Divider()

            if let project = selectedProject {
                List(project.elements, selection: $selectedElementID) { element in
                    VStack(alignment: .leading) {
                        Text(element.name)
                            .fontWeight(.medium)
                        Text("\(element.user)@\(element.ip)\(!element.host.isEmpty ? " (\(element.host))" : ""):\(element.port)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(element.id)
                    .contextMenu {
                        Button("Edit…") {
                            elementEditorConfig = EditorConfig(editingID: element.id)
                        }
                        Button("Delete", role: .destructive) {
                            guard let provID = selectedProviderID, let projID = selectedProjectID else { return }
                            if selectedElementID == element.id {
                                selectedElementID = nil
                            }
                            store.deleteElement(providerID: provID, projectID: projID, elementID: element.id)
                        }
                    }
                }
            } else {
                Spacer()
                Text("Select a project")
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()

            HStack {
                Button(action: {
                    elementEditorConfig = EditorConfig(editingID: nil)
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedProjectID == nil)

                Spacer()

                Button(action: {
                    guard let provID = selectedProviderID,
                          let projID = selectedProjectID,
                          let elemID = selectedElementID else { return }
                    selectedElementID = nil
                    store.deleteElement(providerID: provID, projectID: projID, elementID: elemID)
                }) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedElementID == nil)
            }
            .padding(6)
        }
        .frame(minWidth: 220)
        .sheet(item: $elementEditorConfig) { config in
            if let provID = selectedProviderID, let projID = selectedProjectID {
                ElementEditorView(
                    providerID: provID,
                    projectID: projID,
                    elementID: config.editingID
                )
                .environmentObject(store)
            }
        }
    }
}
