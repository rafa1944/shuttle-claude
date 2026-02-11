import SwiftUI
import AppKit

struct SearchView: View {
    @EnvironmentObject private var store: DataStore
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    @State private var eventMonitor: Any?

    private var results: [SearchResult] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }

        var matches: [SearchResult] = []
        for provider in store.providers {
            for project in provider.projects {
                let projectMatches = project.name.lowercased().contains(query)
                    || (project.url?.lowercased().contains(query) ?? false)

                for element in project.elements {
                    let elementMatches = element.name.lowercased().contains(query)
                        || element.host.lowercased().contains(query)
                        || element.ip.lowercased().contains(query)
                        || element.user.lowercased().contains(query)

                    if projectMatches || elementMatches {
                        matches.append(SearchResult(
                            providerName: provider.name,
                            projectName: project.name,
                            element: element
                        ))
                    }
                }
            }
        }
        return matches
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search by name, IP, user…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .focused($isSearchFocused)
                .padding()
                .onChange(of: searchText) { _ in
                    selectedIndex = 0
                }
                .onSubmit {
                    launchSelected()
                }

            Divider()

            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                Spacer()
                Text("Type to search connections")
                    .foregroundColor(.secondary)
                Spacer()
            } else if results.isEmpty {
                Spacer()
                Text("No results")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            resultRow(result, index: index)
                                .id(index)
                        }
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            isSearchFocused = true
            startMonitoringKeys()
        }
        .onDisappear {
            stopMonitoringKeys()
        }
    }

    private func resultRow(_ result: SearchResult, index: Int) -> some View {
        Button {
            launchElement(result.element)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.element.name)
                        .fontWeight(.medium)
                    HStack(spacing: 4) {
                        Text("\(result.providerName) › \(result.projectName)")
                        Text("·")
                        Text("\(result.element.user)@\(result.element.ip)\(!result.element.host.isEmpty ? " (\(result.element.host))" : ""):\(result.element.port)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(index == selectedIndex ? Color.accentColor.opacity(0.25) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Keyboard Navigation

    private func startMonitoringKeys() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let count = results.count
            guard count > 0 else { return event }

            switch event.keyCode {
            case 125: // Arrow down
                selectedIndex = min(selectedIndex + 1, count - 1)
                return nil
            case 126: // Arrow up
                selectedIndex = max(selectedIndex - 1, 0)
                return nil
            default:
                return event
            }
        }
    }

    private func stopMonitoringKeys() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Actions

    private func launchSelected() {
        let currentResults = results
        guard !currentResults.isEmpty, selectedIndex < currentResults.count else { return }
        launchElement(currentResults[selectedIndex].element)
    }

    private func launchElement(_ element: Element) {
        if store.settings.copySudoOnConnect, let pwd = element.sudoPassword, !pwd.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pwd, forType: .string)
        }
        TerminalLauncher.launch(
            element: element,
            terminal: store.settings.terminalApp,
            customPath: store.settings.customTerminalPath
        )
    }
}

private struct SearchResult: Identifiable {
    let id: UUID
    let providerName: String
    let projectName: String
    let element: Element

    init(providerName: String, projectName: String, element: Element) {
        self.id = element.id
        self.providerName = providerName
        self.projectName = projectName
        self.element = element
    }
}
