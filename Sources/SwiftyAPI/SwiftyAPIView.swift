import SwiftUI

public struct SwiftyAPIView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var source: String
    @State private var format: OpenAPIFormat
    @State private var selectedMode: SwiftyAPIViewMode
    @State private var summary: OpenAPISummary?
    @State private var selectedOperationID: String?
    @State private var selectedGeneratorKey: String
    @State private var isGeneratorSelectorPresented = false
    @State private var operationsPaneWidth: CGFloat = 320
    @State private var codePaneWidth: CGFloat = 360
    @State private var operationsDragStartWidth: CGFloat?
    @State private var codeDragStartWidth: CGFloat?

    private let onChange: (OpenAPIDocument) -> Void
    private let generators: [any SwiftyAPICodeGenerator]

    public init(
        source: String = OpenAPITemplates.minimalYAML,
        format: OpenAPIFormat = .yaml,
        onChange: @escaping (OpenAPIDocument) -> Void = { _ in }
    ) {
        self._source = State(initialValue: source)
        self._format = State(initialValue: format)
        self._selectedMode = State(initialValue: .design)
        self._selectedGeneratorKey = State(initialValue: SwiftyAPICurlExampleGenerator().registryKey)
        self.generators = SwiftyAPIBuiltinGenerators.all
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

                generatorSelector
                    .frame(width: 330)

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

    private var generatorSelector: some View {
        Button {
            isGeneratorSelectorPresented.toggle()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedGenerator?.name ?? "Generator")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        if let selectedGenerator {
                            generatorChip(selectedGenerator.language, color: languageTint(for: selectedGenerator.language))
                            generatorChip(selectedGenerator.type.capitalized, color: typeTint(for: selectedGenerator.type))
                        }
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(nsColor: .separatorColor))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isGeneratorSelectorPresented, arrowEdge: .bottom) {
            generatorSelectorPopover
        }
    }

    private var generatorSelectorPopover: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(generatorChoices, id: \.key) { choice in
                    Button {
                        selectedGeneratorKey = choice.key
                        isGeneratorSelectorPresented = false
                    } label: {
                        generatorSelectorRow(choice)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .frame(width: 440)
        .frame(maxHeight: 480)
    }

    private func generatorSelectorRow(_ choice: GeneratorChoice) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(choice.name)
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if choice.key == selectedGeneratorKey {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text(choice.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                generatorChip(choice.language, color: languageTint(for: choice.language))
                generatorChip(choice.variation, color: variationTint(for: choice.variation))
                generatorChip(choice.platform, color: platformTint(for: choice.platform))
                generatorChip(choice.type.capitalized, color: typeTint(for: choice.type))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(choice.key == selectedGeneratorKey ? Color.accentColor.opacity(0.10) : Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(choice.key == selectedGeneratorKey ? Color.accentColor.opacity(0.45) : Color(nsColor: .separatorColor).opacity(0.65))
        )
    }

    private func generatorChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
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
            SwiftyAPIMonacoEditor(
                text: $source,
                language: sourceMonacoLanguage,
                theme: systemMonacoTheme,
                showsGutter: true,
                isEditable: true
            )
        case .generated:
            generatedView
        }
    }

    private var designWorkbench: some View {
        HStack(spacing: 0) {
            operationsList
                .frame(width: operationsPaneWidth)
                .background(Color(nsColor: .controlBackgroundColor))

            resizingDivider {
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if operationsDragStartWidth == nil {
                            operationsDragStartWidth = operationsPaneWidth
                        }
                        let startWidth = operationsDragStartWidth ?? operationsPaneWidth
                        operationsPaneWidth = clampedPaneWidth(startWidth + value.translation.width, minimum: 240, maximum: 520)
                    }
                    .onEnded { _ in
                        operationsDragStartWidth = nil
                    }
            }

            ScrollView {
                operationDetail
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(28)
            }
            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))

            resizingDivider {
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if codeDragStartWidth == nil {
                            codeDragStartWidth = codePaneWidth
                        }
                        let startWidth = codeDragStartWidth ?? codePaneWidth
                        codePaneWidth = clampedPaneWidth(startWidth - value.translation.width, minimum: 300, maximum: 620)
                    }
                    .onEnded { _ in
                        codeDragStartWidth = nil
                    }
            }

            requestResponseRail
                .frame(width: codePaneWidth)
        }
    }

    private func resizingDivider<GestureType: Gesture>(_ gesture: () -> GestureType) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 9)
            .overlay {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
            .gesture(gesture())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    private func clampedPaneWidth(_ width: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(width, minimum), maximum)
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
                            type: response.schemaName ?? response.contentTypes.first ?? "response",
                            detail: response.description ?? "No response description."
                        )

                        ForEach(response.schemaFields, id: \.displayID) { field in
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

    private var requestResponseRail: some View {
        VStack(spacing: 18) {
            darkCodePanel(
                title: "Request",
                subtitle: selectedGenerator?.name ?? "Generator",
                code: requestCodePreview,
                language: generatorMonacoLanguage
            )

            darkCodePanel(
                title: "Response",
                subtitle: selectedGenerator?.language ?? "Example",
                code: responseCodePreview,
                language: generatorMonacoLanguage
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

    private func darkCodePanel(title: String, subtitle: String, code: String, language: String) -> some View {
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

            SwiftyAPIMonacoEditor(
                text: .constant(code),
                language: language,
                theme: .designBlue,
                showsGutter: false,
                isEditable: false
            )
            .frame(minHeight: 220, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.18))
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

    private var generatedView: some View {
        let result = generatedPreview

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(selectedGenerator?.name ?? "Generator")
                    .font(.headline)
                Text(selectedGenerator?.description ?? "No generator selected.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                if result.files.isEmpty {
                    Text("No generated files.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(result.files, id: \.path) { file in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.path)
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(file.kind.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }

                if result.diagnostics.isEmpty == false {
                    Divider()
                    Text("Diagnostics")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(result.diagnostics.indices, id: \.self) { index in
                        Text(result.diagnostics[index].message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .frame(width: 300)
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if result.files.isEmpty {
                        placeholder(title: "No Generated Output")
                    } else {
                        ForEach(result.files, id: \.path) { file in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(file.path)
                                    .font(.headline)
                                SwiftyAPIMonacoEditor(
                                    text: .constant(file.contents),
                                    language: monacoLanguage(forPath: file.path),
                                    theme: systemMonacoTheme,
                                    showsGutter: true,
                                    isEditable: false
                                )
                                .frame(minHeight: generatedEditorHeight(for: file.contents))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
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
        methodExamplePreview.requestExample
    }

    private var responseCodePreview: String {
        methodExamplePreview.responseExample
    }

    private var methodExamplePreview: SwiftyAPIMethodGeneratorResult {
        guard let operation = selectedOperation else {
            return SwiftyAPIMethodGeneratorResult()
        }

        let context = SwiftyAPIMethodGenerationContext(
            title: summary?.title ?? "Untitled API",
            version: summary?.version ?? "",
            serverURL: summary?.servers.first,
            operation: operation
        )

        return (try? (selectedGenerator ?? SwiftyAPICurlExampleGenerator()).generateMethod(
            from: context,
            options: SwiftyAPIGeneratorOptions()
        )) ?? SwiftyAPIMethodGeneratorResult()
    }

    private var generatedPreview: SwiftyAPIGeneratorResult {
        guard let document = try? OpenAPIDocument(source: source, format: format),
              let generator = selectedGenerator else {
            return SwiftyAPIGeneratorResult()
        }

        return (try? generator.generateFull(
            from: document,
            options: SwiftyAPIGeneratorOptions()
        )) ?? SwiftyAPIGeneratorResult(
            diagnostics: [
                SwiftyAPIGeneratorDiagnostic(
                    severity: .error,
                    message: "The selected generator could not produce output."
                )
            ]
        )
    }

    private var selectedGenerator: (any SwiftyAPICodeGenerator)? {
        generators.first { $0.registryKey == selectedGeneratorKey } ?? generators.first
    }

    private var sourceMonacoLanguage: String {
        switch format {
        case .json:
            return "json"
        case .yaml:
            return "yaml"
        }
    }

    private var systemMonacoTheme: SwiftyAPIMonacoTheme {
        colorScheme == .dark ? .dark : .light
    }

    private var generatorMonacoLanguage: String {
        guard let selectedGenerator else {
            return "plaintext"
        }

        return monacoLanguage(for: selectedGenerator)
    }

    private func monacoLanguage(for generator: any SwiftyAPICodeGenerator) -> String {
        switch generator.language.lowercased() {
        case "curl":
            return "shell"
        case "swift":
            return "swift"
        case "typescript":
            return "typescript"
        case "javascript":
            return "javascript"
        case "python":
            return "python"
        case "c#":
            return "csharp"
        default:
            return "plaintext"
        }
    }

    private func monacoLanguage(forPath path: String) -> String {
        let lowercased = path.lowercased()

        if lowercased.hasSuffix(".swift") { return "swift" }
        if lowercased.hasSuffix(".ts") || lowercased.hasSuffix(".tsx") { return "typescript" }
        if lowercased.hasSuffix(".js") || lowercased.hasSuffix(".jsx") { return "javascript" }
        if lowercased.hasSuffix(".py") { return "python" }
        if lowercased.hasSuffix(".cs") { return "csharp" }
        if lowercased.hasSuffix(".json") { return "json" }
        if lowercased.hasSuffix(".yaml") || lowercased.hasSuffix(".yml") { return "yaml" }
        if lowercased.hasSuffix(".md") { return "markdown" }
        if lowercased.hasSuffix(".sh") { return "shell" }
        return "plaintext"
    }

    private func generatedEditorHeight(for contents: String) -> CGFloat {
        let lineCount = contents.split(separator: "\n", omittingEmptySubsequences: false).count
        return min(max(CGFloat(lineCount * 19 + 34), 180), 760)
    }

    private var generatorChoices: [GeneratorChoice] {
        generators.map { generator in
            GeneratorChoice(
                key: generator.registryKey,
                name: generator.name,
                description: generator.description,
                language: generator.language,
                variation: generator.variation,
                platform: platformName(for: generator),
                type: generator.type
            )
        }
    }

    private func platformName(for generator: any SwiftyAPICodeGenerator) -> String {
        let name = generator.name.lowercased()
        let variation = generator.variation.lowercased()

        if name.contains("curl") { return "Shell" }
        if variation.contains("urlsession") { return "Apple" }
        if variation.contains("vapor") { return "Vapor" }
        if variation.contains("axios") { return "Web" }
        if variation == "node" { return "Node.js" }
        if variation.contains("httpx") { return "httpx" }
        if variation.contains("fastapi") { return "FastAPI" }
        if variation.contains("httpclient") { return ".NET" }
        if variation.contains("asp.net") { return "ASP.NET" }
        return generator.author.capitalized
    }

    private func languageTint(for language: String) -> Color {
        switch language.lowercased() {
        case "swift":
            return Color(red: 0.92, green: 0.25, blue: 0.12)
        case "typescript", "javascript":
            return Color(red: 0.18, green: 0.43, blue: 0.92)
        case "python":
            return Color(red: 0.13, green: 0.48, blue: 0.30)
        case "c#":
            return Color(red: 0.47, green: 0.25, blue: 0.82)
        case "curl":
            return Color(red: 0.46, green: 0.50, blue: 0.56)
        default:
            return .accentColor
        }
    }

    private func typeTint(for type: String) -> Color {
        switch type.lowercased() {
        case "client":
            return Color(red: 0.04, green: 0.54, blue: 0.78)
        case "server":
            return Color(red: 0.72, green: 0.31, blue: 0.09)
        default:
            return .secondary
        }
    }

    private func variationTint(for variation: String) -> Color {
        let lowercased = variation.lowercased()
        if lowercased.contains("vapor") || lowercased.contains("fastapi") || lowercased.contains("asp.net") {
            return Color(red: 0.63, green: 0.33, blue: 0.78)
        }
        if lowercased.contains("axios") || lowercased.contains("httpx") || lowercased.contains("httpclient") || lowercased.contains("urlsession") {
            return Color(red: 0.18, green: 0.45, blue: 0.66)
        }
        return Color(red: 0.42, green: 0.46, blue: 0.54)
    }

    private func platformTint(for platform: String) -> Color {
        switch platform.lowercased() {
        case "apple":
            return Color(red: 0.33, green: 0.36, blue: 0.42)
        case "node.js", "web":
            return Color(red: 0.16, green: 0.48, blue: 0.24)
        case "vapor", "fastapi", "asp.net":
            return Color(red: 0.55, green: 0.24, blue: 0.70)
        case ".net":
            return Color(red: 0.42, green: 0.22, blue: 0.78)
        default:
            return Color(red: 0.44, green: 0.47, blue: 0.52)
        }
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

private struct GeneratorChoice {
    var key: String
    var name: String
    var description: String
    var language: String
    var variation: String
    var platform: String
    var type: String
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
