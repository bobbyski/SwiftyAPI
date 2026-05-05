import SwiftUI
import SwiftyAPI

@main
struct SwiftyAPIDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SwiftyAPIDemoRootView()
        }
    }
}

private struct SwiftyAPIDemoRootView: View {
    @State private var selectedView: DemoViewKind = .new
    @State private var latestDocument: OpenAPIDocument?

    var body: some View {
        Group {
            switch selectedView {
            case .new:
                SwiftyAPIView { document in
                    latestDocument = document
                }
            case .debug:
                SwiftyAPIDebugView { document in
                    latestDocument = document
                }
            }
        }
        .frame(minWidth: 980, minHeight: 680)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    selectedView = .new
                } label: {
                    Label("New View", systemImage: selectedView == .new ? "checkmark.rectangle" : "rectangle")
                }

                Button {
                    selectedView = .debug
                } label: {
                    Label("Debug View", systemImage: selectedView == .debug ? "checkmark.rectangle" : "rectangle")
                }
            }
        }
    }
}

private enum DemoViewKind {
    case new
    case debug
}
