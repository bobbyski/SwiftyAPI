import SwiftUI

public struct SwiftyAPIView: View {
    @State private var source: String
    @State private var format: OpenAPIFormat
    @State private var selectedMode: SwiftyAPIViewMode
    @State private var summary: OpenAPISummary?
    @State private var selectedOperationID: String?

    private let onChange: (OpenAPIDocument) -> Void

    public init(
        source: String = OpenAPITemplates.minimalYAML,
        format: OpenAPIFormat = .yaml,
        onChange: @escaping (OpenAPIDocument) -> Void = { _ in }
    ) {
        self._source = State(initialValue: source)
        self._format = State(initialValue: format)
        self._selectedMode = State(initialValue: .design)
        self.onChange = onChange
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            modeBar

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

    private var modeBar: some View {
        HStack(spacing: 0) {
            ForEach(SwiftyAPIViewMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Text(mode.title)
                        .font(.callout)
                        .fontWeight(selectedMode == mode ? .semibold : .regular)
                        .foregroundStyle(selectedMode == mode ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Rectangle()
                                .fill(selectedMode == mode ? Color(nsColor: .textBackgroundColor) : Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selectedMode == mode ? Color.accentColor : Color.clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedMode {
        case .design:
            designWorkbench
        case .source:
            TextEditor(text: $source)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
        case .generated:
            placeholder(title: "Generated Coming Soon")
        }
    }

    private var designWorkbench: some View {
        HStack(spacing: 0) {
            operationsList
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView {
                operationDetail
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            requestResponseRail
                .frame(width: 360)
        }
    }

    private var operationsList: some View {
        List {
            if let operations = summary?.operations, operations.isEmpty == false {
                ForEach(operationGroups(from: operations), id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.operations) { operation in
                            Button {
                                selectedOperationID = operation.id
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(operation.summary ?? operation.path)
                                            .font(.callout)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(operation.path)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer(minLength: 8)

                                    methodBadge(operation.method)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedOperationID == operation.id ? Color.accentColor.opacity(0.10) : .clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("No operations")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
    }

    private var operationDetail: some View {
        guard let operation = selectedOperation else {
            return AnyView(placeholder(title: "Select an Operation"))
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Operation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(operation.summary ?? operation.operationID ?? operation.path)
                        .font(.system(size: 34, weight: .semibold))

                    HStack(spacing: 8) {
                        methodBadge(operation.method)

                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(operation.path)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("Try it") {}
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Description")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(operation.description ?? operation.summary ?? "No description has been provided for this operation yet.")
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }

                requestCard
                responsesCard
            }
        )
    }

    private var requestCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            let operation = selectedOperation
            let requestBody = operation?.requestBody
            let parameters = operation?.parameters ?? []

            HStack {
                Text("Request")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                if let contentType = requestBody?.contentTypes.first {
                    Text(contentType)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                if parameters.isEmpty, requestBody == nil {
                    Text("No request parameters or body are defined for this operation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(parameters, id: \.displayID) { parameter in
                        parameterRow(
                            name: parameter.name,
                            type: parameter.type ?? parameter.location,
                            detail: parameterDetail(parameter)
                        )
                    }

                    if let requestBody {
                        parameterRow(
                            name: requestBody.schemaName ?? "body",
                            type: requestBody.contentTypes.first ?? "object",
                            detail: requestBodyDetail(requestBody)
                        )

                        ForEach(requestBody.schemaFields, id: \.displayID) { field in
                            parameterRow(
                                name: field.name,
                                type: field.type,
                                detail: schemaFieldDetail(field)
                            )
                            .padding(.leading, 16)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(cardBackground)
    }

    private var responsesCard: some View {
        let responses = selectedOperation?.responses ?? []

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(responseTint(for: responses.first?.statusCode ?? "200"))
                    .frame(width: 12, height: 12)
                Text(responses.first?.statusCode ?? "Response")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(responseTint(for: responses.first?.statusCode ?? "200"))
                Text(responses.first?.description ?? "")
                    .font(.title3)
                Spacer()
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                if responses.isEmpty {
                    Text("No responses are defined for this operation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(responses, id: \.statusCode) { response in
                        parameterRow(
                            name: response.statusCode,
                            type: response.contentTypes.first ?? "response",
                            detail: response.description ?? "No response description."
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(cardBackground)
    }

    private var requestResponseRail: some View {
        VStack(spacing: 18) {
            darkCodePanel(
                title: "Request",
                subtitle: "Shell",
                code: requestCodePreview
            )

            darkCodePanel(
                title: "Response",
                subtitle: "200 - Example 1",
                code: responseCodePreview
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }

    private func parameterRow(name: String, type: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue.opacity(0.08)))
                Text(type)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func parameterDetail(_ parameter: OpenAPIParameter) -> String {
        var parts: [String] = [parameter.location]
        if parameter.isRequired {
            parts.append("required")
        }
        if let description = parameter.description, description.isEmpty == false {
            parts.append(description)
        }
        return parts.joined(separator: " · ")
    }

    private func requestBodyDetail(_ requestBody: OpenAPIRequestBody) -> String {
        var parts: [String] = []
        if requestBody.isRequired {
            parts.append("required")
        }
        if let schemaName = requestBody.schemaName {
            parts.append(schemaName)
        }
        if let description = requestBody.description, description.isEmpty == false {
            parts.append(description)
        }
        if parts.isEmpty {
            return "Request body"
        }
        return parts.joined(separator: " · ")
    }

    private func schemaFieldDetail(_ field: OpenAPISchemaField) -> String {
        var parts: [String] = []
        if field.isRequired {
            parts.append("required")
        }
        if let description = field.description, description.isEmpty == false {
            parts.append(description)
        }
        return parts.isEmpty ? "schema property" : parts.joined(separator: " · ")
    }

    private func responseTint(for statusCode: String) -> Color {
        guard let code = Int(statusCode) else {
            return .secondary
        }

        switch code {
        case 200..<300:
            return .green
        case 300..<400:
            return .blue
        case 400..<500:
            return .orange
        default:
            return .red
        }
    }

    private func darkCodePanel(title: String, subtitle: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.purple.opacity(0.95))
            }
            .padding(16)

            Divider()
                .background(Color.white.opacity(0.12))

            ScrollView {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color(red: 0.62, green: 0.84, blue: 1.0))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(16)
            }
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.04, green: 0.07, blue: 0.13))
        )
    }

    private func methodBadge(_ method: OpenAPIHTTPMethod) -> some View {
        Text(method.rawValue.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(method.tintColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(method.tintColor.opacity(0.12))
            )
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
            selectedOperationID = nil
            return
        }

        summary = document.summary
        if selectedOperationID == nil || document.summary.operations.contains(where: { $0.id == selectedOperationID }) == false {
            selectedOperationID = document.summary.operations.first?.id
        }
        onChange(document)
    }

    private var selectedOperation: OpenAPIOperation? {
        guard let selectedOperationID else {
            return summary?.operations.first
        }

        return summary?.operations.first { $0.id == selectedOperationID }
    }

    private var requestCodePreview: String {
        guard let operation = selectedOperation else {
            return ""
        }

        let baseURL = summary?.servers.first ?? "{{BASE_URL}}"
        let queryParameters = operation.parameters.filter { $0.location == "query" }
        let queryString = queryParameters.isEmpty ? "" : "?" + queryParameters.map { "\($0.name)={\($0.name)}" }.joined(separator: "&")
        let contentType = operation.requestBody?.contentTypes.first
        let bodyLine = operation.requestBody == nil ? "" : " \\\n--data-raw '{}'"
        let headerLine = contentType.map { " \\\n--header 'Content-Type: \($0)'" } ?? ""

        return """
        curl --location --request \(operation.method.rawValue.uppercased()) '\(baseURL)\(operation.path)\(queryString)'\(headerLine)\(bodyLine)
        """
    }

    private var responseCodePreview: String {
        let response = selectedOperation?.responses.first
        let status = response?.statusCode ?? "200"
        let description = response?.description ?? "Example response"
        let contentType = response?.contentTypes.first ?? "application/json"

        return """
        {
          "status": "\(status)",
          "contentType": "\(contentType)",
          "description": "\(description)"
        }
        """
    }

    private func operationGroups(from operations: [OpenAPIOperation]) -> [OperationGroup] {
        let grouped = Dictionary(grouping: operations) { operation in
            operation.path
                .split(separator: "/")
                .first
                .map(String.init) ?? "Root"
        }

        return grouped.keys.sorted().map { key in
            OperationGroup(
                title: key.prefix(1).uppercased() + key.dropFirst(),
                operations: (grouped[key] ?? []).sorted { $0.id < $1.id }
            )
        }
    }
}

private struct OperationGroup {
    var title: String
    var operations: [OpenAPIOperation]
}

private extension OpenAPIParameter {
    var displayID: String {
        "\(location)-\(name)"
    }
}

private extension OpenAPISchemaField {
    var displayID: String {
        "\(name)-\(type)"
    }
}

private extension OpenAPIHTTPMethod {
    var tintColor: Color {
        switch self {
        case .get:
            return .green
        case .post:
            return .orange
        case .put, .patch:
            return .blue
        case .delete:
            return .red
        case .options, .head, .trace:
            return .purple
        }
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
