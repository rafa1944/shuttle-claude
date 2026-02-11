import SwiftUI

struct ProviderMenuSection: View {
    let provider: Provider

    var body: some View {
        if provider.projects.isEmpty {
            Menu(provider.name) {
                Text("No projects")
                    .foregroundColor(.secondary)
            }
        } else {
            Menu(provider.name) {
                ForEach(provider.projects) { project in
                    ProjectMenuSection(project: project)
                }
            }
        }
    }
}
