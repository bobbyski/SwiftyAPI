import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

public extension Notification.Name {
    static let swiftyAPILoadDocument = Notification.Name("SwiftyAPI.loadDocument")
    static let swiftyAPISaveDocument = Notification.Name("SwiftyAPI.saveDocument")
}

public struct SwiftyAPIView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var source: String
    @State private var format: OpenAPIFormat
    @State private var selectedMode: SwiftyAPIViewMode
    @State private var summary: OpenAPISummary?
    @State private var selectedOperationID: String?
    @State private var selectedGeneratorKey: String
    @State private var isGeneratorSelectorPresented = false
    @State private var operationsPaneWidth: CGFloat = 300
    @State private var codePaneWidth: CGFloat = 380
    @State private var operationsDragStartWidth: CGFloat?
    @State private var codeDragStartWidth: CGFloat?
    @State private var suppressNextFormatTranslation = false
    @State private var isEditingOperation = false
    @State private var pendingDelete: OperationDeleteTarget?
    @State private var customGroups: [String] = []
    @State private var selectedGeneratedFilePath: String?

    private let onChange: (OpenAPIDocument) -> Void
    private let generators: [any SwiftyAPICodeGenerator]

    public init(
        source: String = OpenAPITemplates.minimalYAML,
        format: OpenAPIFormat = .yaml,
        generators: [any SwiftyAPICodeGenerator] = SwiftyAPIBuiltinGenerators.all,
        onChange: @escaping (OpenAPIDocument) -> Void = { _ in }
    ) {
        self._source = State(initialValue: source)
        self._format = State(initialValue: format)
        self._selectedMode = State(initialValue: .design)
        self._selectedGeneratorKey = State(initialValue: SwiftyAPICurlExampleGenerator().registryKey)
        self.generators = generators
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
            refreshFormatFromSource()
            publishDocument()
        }
        .alert(item: $pendingDelete) { target in
            Alert(
                title: Text("Are you sure?"),
                message: Text("Delete \(target.title)?"),
                primaryButton: .destructive(Text("Delete")) {
                    performDelete(target)
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: format) { oldFormat, newFormat in
            if suppressNextFormatTranslation {
                suppressNextFormatTranslation = false
                publishDocument()
                return
            }
            translateSource(from: oldFormat, to: newFormat)
            publishDocument()
        }
        #if os(macOS)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    loadSourceFile()
                } label: {
                    Label("Load", systemImage: "folder")
                }

                Button {
                    saveSourceFile()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .swiftyAPILoadDocument)) { _ in
            loadSourceFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .swiftyAPISaveDocument)) { _ in
            saveSourceFile()
        }
        #endif
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

                if selectedMode == .design {
                    Button(isEditingOperation ? "Done" : "Edit") {
                        isEditingOperation.toggle()
                    }
                    .buttonStyle(.bordered)
                }

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
            operationsPane
                .frame(width: operationsPaneWidth)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipped()

            resizingDivider {
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if operationsDragStartWidth == nil {
                            operationsDragStartWidth = operationsPaneWidth
                        }
                        let startWidth = operationsDragStartWidth ?? operationsPaneWidth
                        operationsPaneWidth = clampedPaneWidth(startWidth + value.translation.width, minimum: 260, maximum: 460)
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
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
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

    @ViewBuilder
    private var operationsPane: some View {
        if isEditingOperation {
            editableOperationsList
        } else {
            operationsList
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
                                            .truncationMode(.tail)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(operation.path)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.head)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                                    Spacer(minLength: 8)

                                    methodBadge(operation.method)
                                        .fixedSize()
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

    private var editableOperationsList: some View {
        List {
            if let operations = summary?.operations, operations.isEmpty == false {
                Section("Operations") {
                    ForEach(operations.indices, id: \.self) { index in
                        editableOperationRow(index: index, operation: operations[index])
                    }
                }
            } else {
                Text("No operations")
                    .foregroundStyle(.secondary)
            }

            Button {
                addGroup()
            } label: {
                Label("Add group", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 10))

            Button {
                addOperation()
            } label: {
                Label("Add API call", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        }
        .listStyle(.sidebar)
    }

    private func editableOperationRow(index: Int, operation: OpenAPIOperation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Picker("Method", selection: bindingForOperationMethod(at: index)) {
                    ForEach(OpenAPIHTTPMethod.allCases, id: \.self) { method in
                        Text(method.rawValue.uppercased()).tag(method)
                    }
                }
                .labelsHidden()
                .frame(width: 92)

                Button("-") {
                    pendingDelete = OperationDeleteTarget(
                        title: operation.summary ?? operation.path,
                        kind: .operation(operation.id)
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityLabel("Delete \(operation.summary ?? operation.path)")
            }

            TextField("Summary", text: bindingForOperationString(at: index, \.summary, fallback: operation.summary ?? ""))
                .textFieldStyle(.roundedBorder)
            TextField("Path", text: bindingForOperationPath(at: index))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
            Picker("Group", selection: bindingForOperationGroup(at: index)) {
                ForEach(groupChoices, id: \.self) { group in
                    Text(group).tag(group)
                }
            }
            .labelsHidden()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedOperationID = operation.id
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedOperationID == operation.id ? Color.accentColor.opacity(0.10) : .clear)
                .padding(.vertical, 2)
        )
    }

    private var operationDetail: some View {
        guard let operation = selectedOperation else {
            return AnyView(placeholder(title: "Select an Operation"))
        }

        guard isEditingOperation == false else {
            return AnyView(swiftyAPIEditingView(operation: operation))
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
                                .disabled(true)
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
                sectionSeparator
                responsesCard
            }
        )
    }

    private func swiftyAPIEditingView(operation: OpenAPIOperation) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Operation")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                TextField("Operation title", text: bindingForSelectedOperationString(\.summary, fallback: operation.summary ?? operation.operationID ?? operation.path))
                    .font(.system(size: 34, weight: .semibold))
                    .textFieldStyle(.plain)

                HStack(spacing: 8) {
                    methodBadge(operation.method)

                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Path", text: bindingForSelectedOperationPath())
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.plain)

                        Spacer()

                        Button("Try it") {}
                            .buttonStyle(.borderedProminent)
                            .disabled(true)
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
                TextField(
                    "Description",
                    text: bindingForSelectedOperationString(\.description, fallback: operation.description ?? "")
                )
                .textFieldStyle(.roundedBorder)
            }

            editableRequestCard(operation: operation)
            sectionSeparator
            editableResponsesCard(operation: operation)
        }
    }

    private var sectionSeparator: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.75))
            .frame(height: 1)
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

            VStack(alignment: .leading, spacing: 0) {
                if parameters.isEmpty, requestBody == nil {
                    Text("No request parameters or body are defined for this operation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                } else {
                    detailRows(requestDisplayRows(parameters: parameters, requestBody: requestBody))
                }
            }
            .padding(16)
        }
        .background(cardBackground)
    }

    private var responsesCard: some View {
        let responses = selectedOperation?.responses ?? []

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Responses")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                if responses.isEmpty {
                    Text("No responses are defined for this operation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                } else {
                    ForEach(responses.indices, id: \.self) { index in
                        responseVariantView(responses[index])

                        if index < responses.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(cardBackground)
    }

    private func responseVariantView(_ response: OpenAPIResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            responseStatusHeader(statusCode: response.statusCode, description: response.description)

            let rows = response.schemaFields.map { field in
                DetailRow(
                    id: "response-\(response.statusCode)-\(field.displayID)",
                    group: "response-\(response.statusCode)",
                    name: field.name,
                    type: field.type,
                    detail: schemaFieldDetail(field),
                    indent: 16
                )
            }

            if rows.isEmpty {
                Text(response.schemaName ?? response.contentTypes.first ?? "No response fields are defined.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                detailRows(rows)
            }
        }
        .padding(.vertical, 10)
    }

    private func responseStatusHeader(statusCode: String, description: String?) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(responseTint(for: statusCode))
                .frame(width: 12, height: 12)
            Text(statusCode)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(responseTint(for: statusCode))
            Text(description ?? "")
                .font(.title3)
            Spacer()
        }
    }

    private func editableRequestCard(operation: OpenAPIOperation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Request")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                if let contentType = operation.requestBody?.contentTypes.first {
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

            VStack(alignment: .leading, spacing: 0) {
                if operation.parameters.isEmpty, operation.requestBody == nil {
                    Text("No request parameters or body are defined for this operation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                } else {
                    ForEach(operation.parameters.indices, id: \.self) { index in
                        editableParameterRow(index: index, parameter: operation.parameters[index])

                        if shouldSeparateEditableRequestParameter(at: index, operation: operation) {
                            Divider()
                        }
                    }

                    if let requestBody = operation.requestBody {
                        editableRequestBodyRow(requestBody)
                            .padding(.vertical, 10)
                        ForEach(requestBody.schemaFields.indices, id: \.self) { index in
                            editableRequestBodyFieldRow(index: index, field: requestBody.schemaFields[index])
                                .padding(.leading, 16)
                                .padding(.vertical, 10)
                        }
                    }
                }

                addButton("Add request parameter") {
                    addRequestItem()
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
        .background(cardBackground)
    }

    private func editableResponsesCard(operation: OpenAPIOperation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Responses")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                if operation.responses.isEmpty {
                    Text("No responses are defined for this operation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                } else {
                    ForEach(operation.responses.indices, id: \.self) { responseIndex in
                        editableResponseRow(index: responseIndex, response: operation.responses[responseIndex])

                        ForEach(operation.responses[responseIndex].schemaFields.indices, id: \.self) { fieldIndex in
                            editableResponseFieldRow(
                                responseIndex: responseIndex,
                                fieldIndex: fieldIndex,
                                field: operation.responses[responseIndex].schemaFields[fieldIndex]
                            )
                            .padding(.leading, 16)
                            .padding(.vertical, 10)
                        }

                        addButton("Add response field") {
                            addResponseField(to: responseIndex)
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 10)

                        if responseIndex < operation.responses.count - 1 {
                            Divider()
                        }
                    }
                }

                addButton("Add new response") {
                    addResponse()
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
        .background(cardBackground)
    }

    private func editableParameterRow(index: Int, parameter: OpenAPIParameter) -> some View {
        editableFieldRow(
            name: Binding(
                get: { selectedOperation?.parameters[safe: index]?.name ?? parameter.name },
                set: { newValue in updateSelectedOperation { $0.parameters[index].name = newValue } }
            ),
            type: Binding(
                get: { selectedOperation?.parameters[safe: index]?.type ?? parameter.type ?? "" },
                set: { newValue in updateSelectedOperation { $0.parameters[index].type = newValue.nilIfEmpty } }
            ),
            detail: Binding(
                get: { selectedOperation?.parameters[safe: index]?.description ?? parameter.description ?? "" },
                set: { newValue in updateSelectedOperation { $0.parameters[index].description = newValue.nilIfEmpty } }
            ),
            deleteTitle: parameter.name,
            deleteKind: .parameter(index)
        )
        .padding(.vertical, 10)
    }

    private func editableRequestBodyRow(_ requestBody: OpenAPIRequestBody) -> some View {
        editableFieldRow(
            name: Binding(
                get: { selectedOperation?.requestBody?.schemaName ?? requestBody.schemaName ?? "body" },
                set: { newValue in updateSelectedOperation { $0.requestBody?.schemaName = newValue.nilIfEmpty } }
            ),
            type: Binding(
                get: { selectedOperation?.requestBody?.contentTypes.first ?? requestBody.contentTypes.first ?? "" },
                set: { newValue in updateSelectedOperation { $0.requestBody?.contentTypes = newValue.nilIfEmpty.map { [$0] } ?? [] } }
            ),
            detail: Binding(
                get: { selectedOperation?.requestBody?.description ?? requestBody.description ?? "" },
                set: { newValue in updateSelectedOperation { $0.requestBody?.description = newValue.nilIfEmpty } }
            ),
            deleteTitle: requestBody.schemaName ?? "request body",
            deleteKind: .requestBody
        )
    }

    private func editableRequestBodyFieldRow(index: Int, field: OpenAPISchemaField) -> some View {
        editableFieldRow(
            name: Binding(
                get: { selectedOperation?.requestBody?.schemaFields[safe: index]?.name ?? field.name },
                set: { newValue in updateSelectedOperation { $0.requestBody?.schemaFields[index].name = newValue } }
            ),
            type: Binding(
                get: { selectedOperation?.requestBody?.schemaFields[safe: index]?.type ?? field.type },
                set: { newValue in updateSelectedOperation { $0.requestBody?.schemaFields[index].type = newValue } }
            ),
            detail: Binding(
                get: { selectedOperation?.requestBody?.schemaFields[safe: index]?.description ?? field.description ?? "" },
                set: { newValue in updateSelectedOperation { $0.requestBody?.schemaFields[index].description = newValue.nilIfEmpty } }
            ),
            deleteTitle: field.name,
            deleteKind: .requestBodyField(index)
        )
    }

    private func editableResponseRow(index: Int, response: OpenAPIResponse) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(responseTint(for: response.statusCode))
                .frame(width: 12, height: 12)
                .padding(.top, 9)

            editableFieldRow(
                name: Binding(
                    get: { selectedOperation?.responses[safe: index]?.statusCode ?? response.statusCode },
                    set: { newValue in updateSelectedOperation { $0.responses[index].statusCode = newValue } }
                ),
                type: Binding(
                    get: { selectedOperation?.responses[safe: index]?.schemaName ?? response.schemaName ?? response.contentTypes.first ?? "" },
                    set: { newValue in updateSelectedOperation { $0.responses[index].schemaName = newValue.nilIfEmpty } }
                ),
                detail: Binding(
                    get: { selectedOperation?.responses[safe: index]?.description ?? response.description ?? "" },
                    set: { newValue in updateSelectedOperation { $0.responses[index].description = newValue.nilIfEmpty } }
                ),
                deleteTitle: response.statusCode,
                deleteKind: .response(index)
            )
        }
        .padding(.vertical, 10)
    }

    private func editableResponseFieldRow(responseIndex: Int, fieldIndex: Int, field: OpenAPISchemaField) -> some View {
        editableFieldRow(
            name: Binding(
                get: { selectedOperation?.responses[safe: responseIndex]?.schemaFields[safe: fieldIndex]?.name ?? field.name },
                set: { newValue in updateSelectedOperation { $0.responses[responseIndex].schemaFields[fieldIndex].name = newValue } }
            ),
            type: Binding(
                get: { selectedOperation?.responses[safe: responseIndex]?.schemaFields[safe: fieldIndex]?.type ?? field.type },
                set: { newValue in updateSelectedOperation { $0.responses[responseIndex].schemaFields[fieldIndex].type = newValue } }
            ),
            detail: Binding(
                get: { selectedOperation?.responses[safe: responseIndex]?.schemaFields[safe: fieldIndex]?.description ?? field.description ?? "" },
                set: { newValue in updateSelectedOperation { $0.responses[responseIndex].schemaFields[fieldIndex].description = newValue.nilIfEmpty } }
            ),
            deleteTitle: field.name,
            deleteKind: .responseField(responseIndex: responseIndex, fieldIndex: fieldIndex)
        )
    }

    private func editableFieldRow(
        name: Binding<String>,
        type: Binding<String>,
        detail: Binding<String>,
        deleteTitle: String,
        deleteKind: OperationDeleteKind
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Name", text: name)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 120)
                    TextField("Type", text: type)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
                TextField("Description", text: detail)
                    .textFieldStyle(.roundedBorder)
            }

            Button("-") {
                pendingDelete = OperationDeleteTarget(title: deleteTitle, kind: deleteKind)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityLabel("Delete \(deleteTitle)")
        }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
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

    private func detailRows(_ rows: [DetailRow]) -> some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            parameterRow(name: row.name, type: row.type, detail: row.detail)
                .padding(.leading, row.indent)
                .padding(.vertical, 10)

            if shouldSeparateDetailRow(at: index, in: rows) {
                Divider()
            }
        }
    }

    private func shouldSeparateDetailRow(at index: Int, in rows: [DetailRow]) -> Bool {
        let nextIndex = index + 1
        guard rows.indices.contains(nextIndex) else {
            return false
        }

        return rows[index].group != rows[nextIndex].group
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

    private func requestDisplayRows(parameters: [OpenAPIParameter], requestBody: OpenAPIRequestBody?) -> [DetailRow] {
        var rows = parameters.map { parameter in
            DetailRow(
                id: parameter.displayID,
                group: "parameters",
                name: parameter.name,
                type: parameter.type ?? parameter.location,
                detail: parameterDetail(parameter)
            )
        }

        if let requestBody {
            rows.append(
                DetailRow(
                    id: "request-body",
                    group: "request-body",
                    name: requestBody.schemaName ?? "body",
                    type: requestBody.contentTypes.first ?? "object",
                    detail: requestBodyDetail(requestBody)
                )
            )

            rows.append(
                contentsOf: requestBody.schemaFields.map { field in
                    DetailRow(
                        id: "request-body-\(field.displayID)",
                        group: "request-body",
                        name: field.name,
                        type: field.type,
                        detail: schemaFieldDetail(field),
                        indent: 16
                    )
                }
            )
        }

        return rows
    }

    private func responseDisplayRows(_ responses: [OpenAPIResponse]) -> [DetailRow] {
        responses.flatMap { response in
            [
                DetailRow(
                    id: "response-\(response.statusCode)",
                    group: "response-\(response.statusCode)",
                    name: response.statusCode,
                    type: response.schemaName ?? response.contentTypes.first ?? "response",
                    detail: response.description ?? "No response description."
                )
            ] + response.schemaFields.map { field in
                DetailRow(
                    id: "response-\(response.statusCode)-\(field.displayID)",
                    group: "response-\(response.statusCode)",
                    name: field.name,
                    type: field.type,
                    detail: schemaFieldDetail(field),
                    indent: 16
                )
            }
        }
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
        let selectedFile = selectedGeneratedFile(in: result.files)

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedGenerator?.name ?? "Generator")
                        .font(.headline)

                    Spacer()

                    #if os(macOS)
                    Button {
                        exportGeneratedFilesAsZip(result.files)
                    } label: {
                        Label("Export ZIP", systemImage: "archivebox")
                    }
                    .disabled(result.files.isEmpty)
                    #endif
                }

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
                        Button {
                            selectedGeneratedFilePath = file.path
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.path)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(file.kind.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedFile?.path == file.path ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
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

            VStack(alignment: .leading, spacing: 12) {
                if let selectedFile {
                    HStack {
                        Text(selectedFile.path)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(selectedFile.kind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SwiftyAPIMonacoEditor(
                        text: .constant(selectedFile.contents),
                        language: monacoLanguage(forPath: selectedFile.path),
                        theme: systemMonacoTheme,
                        showsGutter: true,
                        isEditable: false
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                } else {
                    placeholder(title: "No Generated Output")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func selectedGeneratedFile(in files: [SwiftyAPIGeneratedFile]) -> SwiftyAPIGeneratedFile? {
        if let selectedGeneratedFilePath,
           let selected = files.first(where: { $0.path == selectedGeneratedFilePath }) {
            return selected
        }

        return files.first
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

    private func refreshFormatFromSource() {
        let detectedFormat = OpenAPIFormatTranslator.inferFormat(from: source, fallback: format)
        guard detectedFormat != format else {
            return
        }

        suppressNextFormatTranslation = true
        format = detectedFormat
    }

    private func replaceSource(_ newSource: String, suggestedFormat: OpenAPIFormat) {
        let detectedFormat = OpenAPIFormatTranslator.inferFormat(from: newSource, fallback: suggestedFormat)
        if detectedFormat != format {
            suppressNextFormatTranslation = true
            format = detectedFormat
        }
        source = newSource
    }

    #if os(macOS)
    private func loadSourceFile() {
        let panel = NSOpenPanel()
        panel.title = "Load OpenAPI Document"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = Self.openAPIContentTypes

        guard panel.runModal() == .OK,
              let url = panel.url,
              let loadedSource = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        replaceSource(loadedSource, suggestedFormat: OpenAPIFormat.infer(from: url.path))
    }

    private func saveSourceFile() {
        let panel = NSSavePanel()
        panel.title = "Save OpenAPI Document"
        panel.allowedContentTypes = [Self.contentType(for: format)]
        panel.nameFieldStringValue = defaultSaveFilename

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        try? source.write(to: url, atomically: true, encoding: .utf8)
    }

    private func exportGeneratedFilesAsZip(_ files: [SwiftyAPIGeneratedFile]) {
        guard files.isEmpty == false else {
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Generated Code"
        panel.allowedContentTypes = [UTType(filenameExtension: "zip") ?? .archive]
        panel.nameFieldStringValue = defaultGeneratedZipFilename

        guard panel.runModal() == .OK,
              let destinationURL = panel.url else {
            return
        }

        let fileManager = FileManager.default
        let exportRoot = fileManager.temporaryDirectory
            .appendingPathComponent("SwiftyAPIExport-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: exportRoot, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: exportRoot) }

            for file in files {
                let fileURL = exportRoot.appendingPathComponent(sanitizedGeneratedPath(file.path), isDirectory: false)
                try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try file.contents.write(to: fileURL, atomically: true, encoding: .utf8)
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = exportRoot
            process.arguments = ["-qr", destinationURL.path, "."]
            try process.run()
            process.waitUntilExit()
        } catch {
            return
        }
    }

    private static var openAPIContentTypes: [UTType] {
        [
            .json,
            contentType(for: .yaml),
            UTType(filenameExtension: "yml") ?? .plainText,
            .plainText
        ]
    }

    private static func contentType(for format: OpenAPIFormat) -> UTType {
        switch format {
        case .json:
            return .json
        case .yaml:
            return UTType(filenameExtension: "yaml") ?? .plainText
        }
    }

    private var defaultSaveFilename: String {
        let baseName = (summary?.title ?? "openapi")
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")

        let resolvedBaseName = baseName.isEmpty ? "openapi" : baseName
        switch format {
        case .json:
            return "\(resolvedBaseName).json"
        case .yaml:
            return "\(resolvedBaseName).yaml"
        }
    }

    private var defaultGeneratedZipFilename: String {
        let baseName = (summary?.title ?? "swiftyapi-generated")
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")

        let generatorName = (selectedGenerator?.name ?? "generated")
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")

        return "\(baseName.isEmpty ? "swiftyapi" : baseName)-\(generatorName.isEmpty ? "generated" : generatorName).zip"
    }

    private func sanitizedGeneratedPath(_ path: String) -> String {
        let rawComponents = path.split(separator: "/").map { String($0) }
        let components = rawComponents.filter { component in
            component.isEmpty == false && component != "." && component != ".."
        }

        return components.isEmpty ? "Generated.txt" : components.joined(separator: "/")
    }
    #endif

    private func publishDocument() {
        guard let document = try? OpenAPIDocument(source: source, format: format) else {
            summary = nil
            selectedOperationID = nil
            isEditingOperation = false
            return
        }

        summary = document.summary
        if selectedOperationID == nil || document.summary.operations.contains(where: { $0.id == selectedOperationID }) == false {
            selectedOperationID = document.summary.operations.first?.id
            isEditingOperation = false
        }
        onChange(document)
    }

    private var selectedOperation: OpenAPIOperation? {
        guard let selectedOperationID else {
            return summary?.operations.first
        }

        return summary?.operations.first { $0.id == selectedOperationID }
    }

    private func selectedOperationIndex() -> Int? {
        guard let operations = summary?.operations else {
            return nil
        }

        if let selectedOperationID,
           let index = operations.firstIndex(where: { $0.id == selectedOperationID }) {
            return index
        }

        return operations.indices.first
    }

    private func updateSelectedOperation(_ update: (inout OpenAPIOperation) -> Void) {
        guard let index = selectedOperationIndex() else {
            return
        }

        var operation = summary?.operations[index]
        guard operation != nil else {
            return
        }

        update(&operation!)
        summary?.operations[index] = operation!
        selectedOperationID = operation!.id
    }

    private func bindingForSelectedOperationString(
        _ keyPath: WritableKeyPath<OpenAPIOperation, String?>,
        fallback: String
    ) -> Binding<String> {
        Binding(
            get: { selectedOperation?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                updateSelectedOperation { operation in
                    operation[keyPath: keyPath] = newValue.nilIfEmpty
                }
            }
        )
    }

    private func bindingForSelectedOperationPath() -> Binding<String> {
        Binding(
            get: { selectedOperation?.path ?? "" },
            set: { newValue in
                updateSelectedOperation { operation in
                    operation.path = newValue
                }
            }
        )
    }

    private func bindingForOperationString(
        at index: Int,
        _ keyPath: WritableKeyPath<OpenAPIOperation, String?>,
        fallback: String
    ) -> Binding<String> {
        Binding(
            get: { summary?.operations[safe: index]?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                updateOperation(at: index) { operation in
                    operation[keyPath: keyPath] = newValue.nilIfEmpty
                }
            }
        )
    }

    private func bindingForOperationPath(at index: Int) -> Binding<String> {
        Binding(
            get: { summary?.operations[safe: index]?.path ?? "" },
            set: { newValue in
                updateOperation(at: index) { operation in
                    operation.path = newValue
                }
            }
        )
    }

    private func bindingForOperationMethod(at index: Int) -> Binding<OpenAPIHTTPMethod> {
        Binding(
            get: { summary?.operations[safe: index]?.method ?? .get },
            set: { newValue in
                updateOperation(at: index) { operation in
                    operation.method = newValue
                }
            }
        )
    }

    private func bindingForOperationGroup(at index: Int) -> Binding<String> {
        Binding(
            get: { operationGroupTitle(summary?.operations[safe: index]) },
            set: { newValue in
                updateOperation(at: index) { operation in
                    operation.group = newValue.nilIfEmpty
                }
            }
        )
    }

    private var groupChoices: [String] {
        let operationGroups = (summary?.operations ?? []).map { operationGroupTitle($0) }
        let values = Set(operationGroups + customGroups)
        return values.sorted()
    }

    private func updateOperation(at index: Int, _ update: (inout OpenAPIOperation) -> Void) {
        guard summary?.operations.indices.contains(index) == true else {
            return
        }

        var operation = summary!.operations[index]
        update(&operation)
        summary?.operations[index] = operation
        selectedOperationID = operation.id
    }

    private func shouldSeparateEditableRequestParameter(at index: Int, operation: OpenAPIOperation) -> Bool {
        if index < operation.parameters.count - 1 {
            return false
        }

        return operation.requestBody != nil
    }

    private func performDelete(_ target: OperationDeleteTarget) {
        updateSelectedOperation { operation in
            switch target.kind {
            case .operation:
                return
            case .parameter(let index):
                guard operation.parameters.indices.contains(index) else { return }
                operation.parameters.remove(at: index)
            case .requestBody:
                operation.requestBody = nil
            case .requestBodyField(let index):
                guard operation.requestBody?.schemaFields.indices.contains(index) == true else { return }
                operation.requestBody?.schemaFields.remove(at: index)
            case .response(let index):
                guard operation.responses.indices.contains(index) else { return }
                operation.responses.remove(at: index)
            case .responseField(let responseIndex, let fieldIndex):
                guard operation.responses.indices.contains(responseIndex),
                      operation.responses[responseIndex].schemaFields.indices.contains(fieldIndex) else { return }
                operation.responses[responseIndex].schemaFields.remove(at: fieldIndex)
            }
        }

        if case .operation(let operationID) = target.kind {
            deleteOperation(id: operationID)
        }
    }

    private func addGroup() {
        let nextIndex = customGroups.count + 1
        let name = "New Group \(nextIndex)"
        customGroups.append(name)
    }

    private func addOperation() {
        let operationNumber = (summary?.operations.count ?? 0) + 1
        let operation = OpenAPIOperation(
            method: .get,
            path: "/new-operation-\(operationNumber)",
            group: groupChoices.first ?? "New Group",
            summary: "New API call",
            description: "Describe this API call.",
            responses: [
                OpenAPIResponse(statusCode: "200", description: "Success.")
            ]
        )

        summary?.operations.append(operation)
        selectedOperationID = operation.id
    }

    private func deleteOperation(id operationID: String) {
        guard var operations = summary?.operations,
              let index = operations.firstIndex(where: { $0.id == operationID }) else {
            return
        }

        operations.remove(at: index)
        summary?.operations = operations

        if selectedOperationID == operationID {
            selectedOperationID = operations[safe: min(index, operations.count - 1)]?.id ?? operations.last?.id
        }
    }

    private func addRequestItem() {
        updateSelectedOperation { operation in
            if operation.requestBody != nil {
                let nextIndex = (operation.requestBody?.schemaFields.count ?? 0) + 1
                operation.requestBody?.schemaFields.append(
                    OpenAPISchemaField(
                        name: "field\(nextIndex)",
                        type: "string",
                        description: "New request field."
                    )
                )
            } else {
                let nextIndex = operation.parameters.count + 1
                operation.parameters.append(
                    OpenAPIParameter(
                        name: "parameter\(nextIndex)",
                        location: "query",
                        type: "string",
                        description: "New request parameter."
                    )
                )
            }
        }
    }

    private func addResponse() {
        updateSelectedOperation { operation in
            operation.responses.append(
                OpenAPIResponse(
                    statusCode: "200",
                    description: "Success.",
                    contentTypes: ["application/json"]
                )
            )
        }
    }

    private func addResponseField(to responseIndex: Int) {
        updateSelectedOperation { operation in
            guard operation.responses.indices.contains(responseIndex) else {
                return
            }

            let nextIndex = operation.responses[responseIndex].schemaFields.count + 1
            operation.responses[responseIndex].schemaFields.append(
                OpenAPISchemaField(
                    name: "field\(nextIndex)",
                    type: "string",
                    description: "New response field."
                )
            )
        }
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
            operationGroupTitle(operation)
        }

        return grouped.keys.sorted().map { key in
            OperationGroup(
                title: key,
                operations: (grouped[key] ?? []).sorted { $0.id < $1.id }
            )
        }
    }

    private func operationGroupTitle(_ operation: OpenAPIOperation?) -> String {
        guard let operation else {
            return "Root"
        }

        if let group = operation.group?.trimmingCharacters(in: .whitespacesAndNewlines),
           group.isEmpty == false {
            return group
        }

        let pathGroup = operation.path
            .split(separator: "/")
            .first
            .map(String.init) ?? "Root"

        return pathGroup.prefix(1).uppercased() + pathGroup.dropFirst()
    }
}

private struct OperationGroup {
    var title: String
    var operations: [OpenAPIOperation]
}

private struct DetailRow {
    var id: String
    var group: String
    var name: String
    var type: String
    var detail: String
    var indent: CGFloat = 0
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

private struct OperationDeleteTarget: Identifiable {
    let id = UUID()
    var title: String
    var kind: OperationDeleteKind
}

private enum OperationDeleteKind {
    case operation(String)
    case parameter(Int)
    case requestBody
    case requestBodyField(Int)
    case response(Int)
    case responseField(responseIndex: Int, fieldIndex: Int)
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

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
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
