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
    @State private var selectedSample: DemoSample = .museum
    @State private var latestDocument: OpenAPIDocument?

    var body: some View {
        let sampleDocument = selectedSample.document

        Group {
            switch selectedView {
            case .new:
                SwiftyAPIView(source: sampleDocument.source, format: sampleDocument.format) { document in
                    latestDocument = document
                }
                .id("\(selectedView.rawValue)-\(selectedSample.rawValue)")
            case .debug:
                SwiftyAPIDebugView(source: sampleDocument.source, format: sampleDocument.format) { document in
                    latestDocument = document
                }
                .id("\(selectedView.rawValue)-\(selectedSample.rawValue)")
            }
        }
        .frame(minWidth: 980, minHeight: 680)
        .toolbar {
            ToolbarItem {
                Picker("Sample", selection: $selectedSample) {
                    ForEach(DemoSample.allCases, id: \.self) { sample in
                        Text(sample.title).tag(sample)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 190)
            }

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

private enum DemoViewKind: String {
    case new
    case debug
}

private enum DemoSample: String, CaseIterable {
    case museum
    case petstore

    var title: String {
        switch self {
        case .museum:
            return "Redocly Museum API"
        case .petstore:
            return "Original Petstore"
        }
    }

    var document: DemoSampleDocument {
        Self.cachedDocuments[self] ?? DemoSampleDocument(source: OpenAPITemplates.minimalYAML, format: .yaml)
    }

    private static let cachedDocuments: [DemoSample: DemoSampleDocument] = [
        .museum: DemoSampleDocument(
            source: loadResource(named: "museum-api", fileExtension: "yaml"),
            format: .yaml
        ),
        .petstore: DemoSampleDocument(
            source: loadResource(named: "petstore-swagger", fileExtension: "json"),
            format: .json
        )
    ]

    private static func loadResource(named name: String, fileExtension: String) -> String {
        let resourceURL: URL?

        #if SWIFT_PACKAGE
        resourceURL = Bundle.module.url(forResource: name, withExtension: fileExtension)
        #else
        resourceURL = Bundle.main.url(forResource: name, withExtension: fileExtension)
        #endif

        guard let resourceURL, let source = try? String(contentsOf: resourceURL, encoding: .utf8) else {
            return OpenAPITemplates.minimalYAML
        }

        return source
    }
}

private struct DemoSampleDocument {
    var source: String
    var format: OpenAPIFormat
}
