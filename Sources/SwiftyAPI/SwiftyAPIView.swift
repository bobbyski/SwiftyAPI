import SwiftUI

public struct SwiftyAPIView: View {
    @State private var source: String
    @State private var format: OpenAPIFormat
    @State private var summary: OpenAPISummary?
    @State private var validationMessage: String?

    private let onChange: (OpenAPIDocument) -> Void

    public init(
        source: String = OpenAPITemplates.minimalYAML,
        format: OpenAPIFormat = .yaml,
        onChange: @escaping (OpenAPIDocument) -> Void = { _ in }
    ) {
        self._source = State(initialValue: source)
        self._format = State(initialValue: format)
        self.onChange = onChange
    }

    public var body: some View {
        NavigationSplitView {
            List {
                Section("Document") {
                    Picker("Format", selection: $format) {
                        ForEach(OpenAPIFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    statusRow
                }

                if let summary {
                    Section("Info") {
                        LabeledContent("Title", value: summary.title)
                        LabeledContent("Version", value: summary.version)
                        LabeledContent("Spec", value: summary.openAPIVersion)
                    }

                    if summary.servers.isEmpty == false {
                        Section("Servers") {
                            ForEach(summary.servers, id: \.self) { server in
                                Text(server)
                            }
                        }
                    }

                    Section("Operations") {
                        if summary.operations.isEmpty {
                            ContentUnavailableView("No Operations", systemImage: "point.3.connected.trianglepath.dotted")
                        } else {
                            ForEach(summary.operations) { operation in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(operation.id)
                                        .font(.headline)
                                    if let summary = operation.summary {
                                        Text(summary)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("SwiftyAPI")
            .frame(minWidth: 280)
        } detail: {
            VStack(spacing: 0) {
                TextEditor(text: $source)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .onChange(of: source) { _, _ in
                        validate()
                    }
                    .onChange(of: format) { _, _ in
                        validate()
                    }
            }
            .navigationTitle("OpenAPI Source")
        }
        .onAppear(perform: validate)
    }

    private var statusRow: some View {
        HStack {
            Image(systemName: validationMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(validationMessage == nil ? .green : .orange)
            Text(validationMessage ?? "Valid OpenAPI document")
                .lineLimit(3)
        }
    }

    private func validate() {
        do {
            let document = try OpenAPIDocument(source: source, format: format)
            summary = document.summary
            validationMessage = nil
            onChange(document)
        } catch {
            summary = nil
            validationMessage = error.localizedDescription
        }
    }
}
