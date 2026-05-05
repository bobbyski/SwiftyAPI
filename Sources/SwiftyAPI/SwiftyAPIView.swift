import SwiftUI

public struct SwiftyAPIView: View {
    @State private var source: String
    @State private var format: OpenAPIFormat
    @State private var selectedMode: SwiftyAPIViewMode
    @State private var summary: OpenAPISummary?

    private let onChange: (OpenAPIDocument) -> Void

    public init(
        source: String = OpenAPITemplates.minimalYAML,
        format: OpenAPIFormat = .yaml,
        onChange: @escaping (OpenAPIDocument) -> Void = { _ in }
    ) {
        self._source = State(initialValue: source)
        self._format = State(initialValue: format)
        self._selectedMode = State(initialValue: .source)
        self.onChange = onChange
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Picker("View", selection: $selectedMode) {
                ForEach(SwiftyAPIViewMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear(perform: publishDocument)
        .onChange(of: source) { _, _ in
            publishDocument()
        }
        .onChange(of: format) { oldFormat, newFormat in
            translateSource(from: oldFormat, to: newFormat)
            publishDocument()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary?.title ?? "Untitled API")
                        .font(.headline)
                    HStack(spacing: 14) {
                        metadataText(label: "Version", value: summary?.version ?? "-")
                        metadataText(label: "Spec", value: summary?.openAPIVersion ?? "-")
                    }
                }

                Spacer()

                Picker("Format", selection: $format) {
                    ForEach(OpenAPIFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Servers")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let servers = summary?.servers, servers.isEmpty == false {
                    Text(servers.joined(separator: ", "))
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("-")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }
        }
        .padding(12)
    }

    private func metadataText(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
        .font(.caption)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedMode {
        case .design:
            HStack(spacing: 0) {
                operationsList
                    .frame(minWidth: 260, idealWidth: 320, maxWidth: 380)

                Divider()

                placeholder(title: "Design Coming Soon")
            }
        case .source:
            TextEditor(text: $source)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
        case .generated:
            placeholder(title: "Generated Coming Soon")
        }
    }

    private var operationsList: some View {
        List {
            Section("Operations") {
                if let operations = summary?.operations, operations.isEmpty == false {
                    ForEach(operations) { operation in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(operation.id)
                                .font(.headline)
                            if let summary = operation.summary {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("No operations")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func placeholder(title: String) -> some View {
        VStack {
            Spacer()
            Text(title)
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func translateSource(from oldFormat: OpenAPIFormat, to newFormat: OpenAPIFormat) {
        let detectedFormat = OpenAPIFormatTranslator.inferFormat(from: source, fallback: oldFormat)
        guard detectedFormat != newFormat else {
            return
        }

        do {
            source = try OpenAPIFormatTranslator.convert(source: source, from: detectedFormat, to: newFormat)
        } catch {
            return
        }
    }

    private func publishDocument() {
        guard let document = try? OpenAPIDocument(source: source, format: format) else {
            summary = nil
            return
        }

        summary = document.summary
        onChange(document)
    }
}

private enum SwiftyAPIViewMode: CaseIterable {
    case design
    case source
    case generated

    var title: String {
        switch self {
        case .design:
            return "Design"
        case .source:
            return "Source"
        case .generated:
            return "Generated"
        }
    }
}
