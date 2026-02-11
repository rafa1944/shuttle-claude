import SwiftUI

struct ProjectMenuSection: View {
    let project: Project

    var body: some View {
        if project.elements.isEmpty {
            Menu(project.name) {
                Text("No elements")
                    .foregroundColor(.secondary)
            }
        } else {
            Menu(project.name) {
                ForEach(project.elements) { element in
                    ElementMenuRow(element: element)
                }
            }
        }
    }
}
