import SwiftUI
import SwiftyAPI

@main
struct SwiftyAPIDemoApp: App {
    @State private var latestDocument: OpenAPIDocument?

    var body: some Scene {
        WindowGroup {
            SwiftyAPIView { document in
                latestDocument = document
            }
            .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            CommandMenu("SwiftyAPI") {
                Button("Print Generated Endpoints") {
                    guard let latestDocument else {
                        return
                    }
                    print(SwiftEndpointGenerator.generate(document: latestDocument))
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }
    }
}
