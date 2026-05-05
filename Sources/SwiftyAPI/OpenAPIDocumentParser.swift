import Foundation

public enum OpenAPIDocumentParser {
    public static func parse(source: String, format: OpenAPIFormat) throws -> OpenAPISummary {
        guard source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw OpenAPIParseError.emptyDocument
        }

        switch format {
        case .json:
            return try parseJSON(source)
        case .yaml:
            return try parseYAML(source)
        }
    }

    private static func parseJSON(_ source: String) throws -> OpenAPISummary {
        do {
            let data = Data(source.utf8)
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                throw OpenAPIParseError.invalidJSON("Root value must be an object.")
            }

            guard let openAPIVersion = dictionary["openapi"] as? String ?? dictionary["swagger"] as? String else {
                throw OpenAPIParseError.missingOpenAPIVersion
            }

            let info = dictionary["info"] as? [String: Any]
            let paths = dictionary["paths"] as? [String: Any] ?? [:]
            let servers = (dictionary["servers"] as? [[String: Any]] ?? [])
                .compactMap { $0["url"] as? String }

            let parameterComponents = dictionary.dictionary(at: "components")?.dictionary(at: "parameters") ?? [:]
            let responseComponents = dictionary.dictionary(at: "components")?.dictionary(at: "responses") ?? [:]
            let requestBodyComponents = dictionary.dictionary(at: "components")?.dictionary(at: "requestBodies") ?? [:]
            let schemaComponents = dictionary.dictionary(at: "components")?.dictionary(at: "schemas") ?? [:]

            return OpenAPISummary(
                openAPIVersion: openAPIVersion,
                title: info?["title"] as? String ?? "Untitled API",
                version: info?["version"] as? String ?? "0.0.0",
                servers: servers,
                operations: parseJSONOperations(
                    paths: paths,
                    parameterComponents: parameterComponents,
                    responseComponents: responseComponents,
                    requestBodyComponents: requestBodyComponents,
                    schemaComponents: schemaComponents
                )
            )
        } catch let parseError as OpenAPIParseError {
            throw parseError
        } catch {
            throw OpenAPIParseError.invalidJSON(error.localizedDescription)
        }
    }

    private static func parseJSONOperations(
        paths: [String: Any],
        parameterComponents: [String: Any],
        responseComponents: [String: Any],
        requestBodyComponents: [String: Any],
        schemaComponents: [String: Any]
    ) -> [OpenAPIOperation] {
        var operations: [OpenAPIOperation] = []

        for path in paths.keys.sorted() {
            guard let pathObject = paths[path] as? [String: Any] else {
                continue
            }

            let pathParameters = parseJSONParameters(
                pathObject["parameters"],
                components: parameterComponents
            )

            for method in OpenAPIHTTPMethod.allCases where pathObject[method.rawValue] != nil {
                let operationObject = pathObject[method.rawValue] as? [String: Any]
                let operationParameters = parseJSONParameters(
                    operationObject?["parameters"],
                    components: parameterComponents
                )
                operations.append(
                    OpenAPIOperation(
                        method: method,
                        path: path,
                        operationID: operationObject?["operationId"] as? String,
                        summary: operationObject?["summary"] as? String,
                        description: operationObject?["description"] as? String,
                        parameters: pathParameters + operationParameters,
                        requestBody: parseJSONRequestBody(
                            operationObject?["requestBody"],
                            components: requestBodyComponents,
                            schemaComponents: schemaComponents
                        ),
                        responses: parseJSONResponses(
                            operationObject?["responses"],
                            components: responseComponents
                        )
                    )
                )
            }
        }

        return operations
    }

    private static func parseJSONParameters(_ value: Any?, components: [String: Any]) -> [OpenAPIParameter] {
        guard let values = value as? [Any] else {
            return []
        }

        return values.compactMap { item in
            let resolved = resolveJSONObject(item, components: components)
            guard let name = resolved["name"] as? String else {
                return nil
            }

            return OpenAPIParameter(
                name: name,
                location: resolved["in"] as? String ?? "query",
                isRequired: resolved["required"] as? Bool ?? false,
                type: schemaType(from: resolved["schema"]),
                description: resolved["description"] as? String
            )
        }
    }

    private static func parseJSONRequestBody(
        _ value: Any?,
        components: [String: Any],
        schemaComponents: [String: Any]
    ) -> OpenAPIRequestBody? {
        let resolved = resolveJSONObject(value, components: components)
        guard resolved.isEmpty == false else {
            return nil
        }

        let content = resolved["content"] as? [String: Any] ?? [:]
        let schema = content
            .values
            .compactMap { ($0 as? [String: Any])?["schema"] }
            .first
        let schemaName = schemaReferenceName(from: schema)

        return OpenAPIRequestBody(
            isRequired: resolved["required"] as? Bool ?? false,
            contentTypes: content.keys.sorted(),
            description: resolved["description"] as? String,
            schemaName: schemaName,
            schemaFields: parseJSONSchemaFields(schema, components: schemaComponents)
        )
    }

    private static func parseJSONResponses(_ value: Any?, components: [String: Any]) -> [OpenAPIResponse] {
        guard let responses = value as? [String: Any] else {
            return []
        }

        return responses.keys.sorted { lhs, rhs in
            responseSortKey(lhs) < responseSortKey(rhs)
        }.map { statusCode in
            let resolved = resolveJSONObject(responses[statusCode], components: components)
            let content = resolved["content"] as? [String: Any] ?? [:]
            return OpenAPIResponse(
                statusCode: statusCode,
                description: resolved["description"] as? String,
                contentTypes: content.keys.sorted()
            )
        }
    }

    private static func resolveJSONObject(_ value: Any?, components: [String: Any]) -> [String: Any] {
        guard let object = value as? [String: Any] else {
            return [:]
        }

        if let ref = object["$ref"] as? String,
           let componentName = ref.split(separator: "/").last.map(String.init),
           let resolved = components[componentName] as? [String: Any] {
            return resolved
        }

        return object
    }

    private static func schemaType(from value: Any?) -> String? {
        guard let schema = value as? [String: Any] else {
            return nil
        }

        if let type = schema["type"] as? String {
            if type == "array", let itemType = schemaType(from: schema["items"]) {
                return "[\(itemType)]"
            }
            return type
        }

        if let ref = schema["$ref"] as? String {
            return ref.split(separator: "/").last.map(String.init)
        }

        return nil
    }

    private static func schemaReferenceName(from value: Any?) -> String? {
        guard let schema = value as? [String: Any],
              let ref = schema["$ref"] as? String else {
            return nil
        }

        return ref.split(separator: "/").last.map(String.init)
    }

    private static func parseJSONSchemaFields(_ value: Any?, components: [String: Any]) -> [OpenAPISchemaField] {
        let schema = resolveJSONObject(value, components: components)
        let properties = schema["properties"] as? [String: Any] ?? [:]
        let required = Set(schema["required"] as? [String] ?? [])

        return properties.keys.sorted().compactMap { name in
            guard let property = properties[name] as? [String: Any] else {
                return nil
            }

            return OpenAPISchemaField(
                name: name,
                type: schemaType(from: property) ?? "object",
                isRequired: required.contains(name),
                description: property["description"] as? String
            )
        }
    }

    private static func parseYAML(_ source: String) throws -> OpenAPISummary {
        let lines = source.components(separatedBy: .newlines)
        let openAPIVersion = firstScalar(in: lines, keys: ["openapi", "swagger"])

        guard let openAPIVersion else {
            throw OpenAPIParseError.missingOpenAPIVersion
        }

        let parameterComponents = yamlComponentObjects(in: lines, section: "parameters")
        let responseComponents = yamlComponentObjects(in: lines, section: "responses")
        let requestBodyComponents = yamlComponentObjects(in: lines, section: "requestBodies")
        let schemaComponents = yamlComponentObjects(in: lines, section: "schemas")

        return OpenAPISummary(
            openAPIVersion: openAPIVersion,
            title: nestedScalar(in: lines, parent: "info", child: "title") ?? "Untitled API",
            version: nestedScalar(in: lines, parent: "info", child: "version") ?? "0.0.0",
            servers: yamlServers(in: lines),
            operations: yamlOperations(
                in: lines,
                parameterComponents: parameterComponents,
                responseComponents: responseComponents,
                requestBodyComponents: requestBodyComponents,
                schemaComponents: schemaComponents
            )
        )
    }

    private static func firstScalar(in lines: [String], keys: [String]) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for key in keys {
                if let value = scalarValue(from: trimmed, key: key) {
                    return value
                }
            }
        }
        return nil
    }

    private static func nestedScalar(in lines: [String], parent: String, child: String) -> String? {
        var isInsideParent = false
        let parentPrefix = "\(parent):"
        let childPrefix = "\(child):"

        for line in lines {
            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if indent == 0 {
                isInsideParent = trimmed == parentPrefix
                continue
            }

            if isInsideParent, trimmed.hasPrefix(childPrefix) {
                return scalarValue(from: trimmed, key: child)
            }
        }

        return nil
    }

    private static func yamlServers(in lines: [String]) -> [String] {
        var servers: [String] = []
        var isInsideServers = false

        for line in lines {
            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if indent == 0 {
                isInsideServers = trimmed == "servers:"
                continue
            }

            if isInsideServers, let range = trimmed.range(of: "url:") {
                let value = String(trimmed[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    .unquoted()
                if value.isEmpty == false {
                    servers.append(value)
                }
            }
        }

        return servers
    }

    private static func yamlOperations(
        in lines: [String],
        parameterComponents: [String: [YAMLLine]],
        responseComponents: [String: [YAMLLine]],
        requestBodyComponents: [String: [YAMLLine]],
        schemaComponents: [String: [YAMLLine]]
    ) -> [OpenAPIOperation] {
        var operations: [OpenAPIOperation] = []
        var isInsidePaths = false
        var currentPath: String?
        var currentMethod: OpenAPIHTTPMethod?
        var currentBlock: [YAMLLine] = []

        func flush() {
            guard let path = currentPath, let method = currentMethod else {
                return
            }
            let block = currentBlock
            operations.append(
                OpenAPIOperation(
                    method: method,
                    path: path,
                    operationID: yamlScalar(in: block, key: "operationId"),
                    summary: yamlScalar(in: block, key: "summary"),
                    description: yamlScalar(in: block, key: "description"),
                    parameters: parseYAMLParameters(from: block, components: parameterComponents),
                    requestBody: parseYAMLRequestBody(
                        from: block,
                        components: requestBodyComponents,
                        schemaComponents: schemaComponents
                    ),
                    responses: parseYAMLResponses(from: block, components: responseComponents)
                )
            )
            currentMethod = nil
            currentBlock = []
        }

        for line in lines {
            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if indent == 0 {
                flush()
                isInsidePaths = trimmed == "paths:"
                currentPath = nil
                continue
            }

            guard isInsidePaths else {
                continue
            }

            if indent == 2, trimmed.hasSuffix(":") {
                flush()
                currentPath = String(trimmed.dropLast()).unquoted()
                continue
            }

            if indent == 4, trimmed.hasSuffix(":") {
                flush()
                let methodName = String(trimmed.dropLast())
                currentMethod = OpenAPIHTTPMethod(rawValue: methodName)
                currentBlock = []
                continue
            }

            if currentMethod != nil, indent >= 6 {
                currentBlock.append(YAMLLine(indent: indent, text: trimmed))
            }
        }

        flush()
        return operations
    }

    private static func yamlComponentObjects(in lines: [String], section: String) -> [String: [YAMLLine]] {
        var objects: [String: [YAMLLine]] = [:]
        var isInsideComponents = false
        var isInsideSection = false
        var currentName: String?

        for line in lines {
            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if indent == 0 {
                isInsideComponents = trimmed == "components:"
                isInsideSection = false
                currentName = nil
                continue
            }

            guard isInsideComponents else {
                continue
            }

            if indent == 2 {
                isInsideSection = trimmed == "\(section):"
                currentName = nil
                continue
            }

            guard isInsideSection else {
                continue
            }

            if indent == 4, trimmed.hasSuffix(":") {
                currentName = String(trimmed.dropLast()).unquoted()
                objects[currentName ?? ""] = []
                continue
            }

            if let currentName, indent >= 6 {
                objects[currentName, default: []].append(YAMLLine(indent: indent, text: trimmed))
            }
        }

        return objects.filter { $0.key.isEmpty == false }
    }

    private static func parseYAMLParameters(from block: [YAMLLine], components: [String: [YAMLLine]]) -> [OpenAPIParameter] {
        let refs = yamlReferences(in: block, parent: "parameters")
        var parameters = refs.compactMap { parseYAMLParameter(from: components[$0] ?? []) }

        let inlineBlocks = yamlArrayObjects(in: block, parent: "parameters")
        parameters.append(contentsOf: inlineBlocks.compactMap { parseYAMLParameter(from: $0) })
        return parameters
    }

    private static func parseYAMLParameter(from block: [YAMLLine]) -> OpenAPIParameter? {
        guard let name = yamlScalar(in: block, key: "name") else {
            return nil
        }

        return OpenAPIParameter(
            name: name,
            location: yamlScalar(in: block, key: "in") ?? "query",
            isRequired: yamlBool(in: block, key: "required"),
            type: yamlSchemaType(in: block),
            description: yamlScalar(in: block, key: "description")
        )
    }

    private static func parseYAMLRequestBody(
        from block: [YAMLLine],
        components: [String: [YAMLLine]],
        schemaComponents: [String: [YAMLLine]]
    ) -> OpenAPIRequestBody? {
        var bodyBlock = yamlNestedBlock(in: block, parent: "requestBody")
        if let ref = yamlReference(in: bodyBlock) {
            bodyBlock = components[ref] ?? bodyBlock
        }

        guard bodyBlock.isEmpty == false else {
            return nil
        }

        let schemaBlock = yamlNestedBlock(in: bodyBlock, parent: "schema")
        let schemaName = yamlReference(in: schemaBlock)
        let resolvedSchemaBlock = schemaName.flatMap { schemaComponents[$0] } ?? schemaBlock

        return OpenAPIRequestBody(
            isRequired: yamlBool(in: bodyBlock, key: "required"),
            contentTypes: yamlContentTypes(in: bodyBlock),
            description: yamlScalar(in: bodyBlock, key: "description"),
            schemaName: schemaName,
            schemaFields: parseYAMLSchemaFields(from: resolvedSchemaBlock)
        )
    }

    private static func parseYAMLResponses(from block: [YAMLLine], components: [String: [YAMLLine]]) -> [OpenAPIResponse] {
        let responseBlock = yamlNestedBlock(in: block, parent: "responses")
        let responseIndent = responseBlock
            .filter { $0.text.hasSuffix(":") }
            .map(\.indent)
            .min()
        var responses: [OpenAPIResponse] = []

        for index in responseBlock.indices {
            let line = responseBlock[index]
            guard line.text.hasSuffix(":"), line.indent == responseIndent else {
                continue
            }

            let statusCode = String(line.text.dropLast()).unquoted()
            guard statusCode.isEmpty == false else {
                continue
            }

            let nested = nestedLines(after: index, in: responseBlock, parentIndent: line.indent)
            let resolved = yamlReference(in: nested).flatMap { components[$0] } ?? nested
            responses.append(
                OpenAPIResponse(
                    statusCode: statusCode,
                    description: yamlScalar(in: resolved, key: "description"),
                    contentTypes: yamlContentTypes(in: resolved)
                )
            )
        }

        return responses.sorted { lhs, rhs in
            responseSortKey(lhs.statusCode) < responseSortKey(rhs.statusCode)
        }
    }

    private static func responseSortKey(_ statusCode: String) -> String {
        String(format: "%04d-%@", Int(statusCode) ?? 9999, statusCode)
    }

    private static func yamlScalar(in lines: [YAMLLine], key: String) -> String? {
        for line in lines {
            if let value = scalarValue(from: line.text, key: key), value.isEmpty == false {
                return value
            }
        }
        return nil
    }

    private static func yamlBool(in lines: [YAMLLine], key: String) -> Bool {
        yamlScalar(in: lines, key: key)?.lowercased() == "true"
    }

    private static func yamlReference(in lines: [YAMLLine]) -> String? {
        yamlScalar(in: lines, key: "$ref")?.split(separator: "/").last.map(String.init)
    }

    private static func yamlReferences(in lines: [YAMLLine], parent: String) -> [String] {
        yamlNestedBlock(in: lines, parent: parent).compactMap { line in
            scalarValue(from: line.text.removingListMarker(), key: "$ref")?.split(separator: "/").last.map(String.init)
        }
    }

    private static func yamlNestedBlock(in lines: [YAMLLine], parent: String) -> [YAMLLine] {
        guard let parentIndex = lines.firstIndex(where: { $0.text == "\(parent):" }) else {
            return []
        }
        return nestedLines(after: parentIndex, in: lines, parentIndent: lines[parentIndex].indent)
    }

    private static func nestedLines(after index: Int, in lines: [YAMLLine], parentIndent: Int) -> [YAMLLine] {
        var nested: [YAMLLine] = []

        for line in lines.dropFirst(index + 1) {
            if line.indent <= parentIndent {
                break
            }
            nested.append(line)
        }

        return nested
    }

    private static func yamlArrayObjects(in lines: [YAMLLine], parent: String) -> [[YAMLLine]] {
        let block = yamlNestedBlock(in: lines, parent: parent)
        var objects: [[YAMLLine]] = []
        var current: [YAMLLine] = []
        var currentIndent: Int?

        for line in block {
            if line.text.hasPrefix("- ") {
                if current.isEmpty == false {
                    objects.append(current)
                }
                currentIndent = line.indent
                current = [YAMLLine(indent: line.indent, text: line.text.removingListMarker())]
                continue
            }

            if let currentIndent, line.indent > currentIndent {
                current.append(line)
            }
        }

        if current.isEmpty == false {
            objects.append(current)
        }

        return objects
    }

    private static func yamlContentTypes(in lines: [YAMLLine]) -> [String] {
        let contentBlock = yamlNestedBlock(in: lines, parent: "content")
        return contentBlock.compactMap { line in
            guard line.text.hasSuffix(":") else {
                return nil
            }

            let value = String(line.text.dropLast()).unquoted()
            return value.contains("/") ? value : nil
        }
    }

    private static func yamlSchemaType(in lines: [YAMLLine]) -> String? {
        let schemaBlock = yamlNestedBlock(in: lines, parent: "schema")
        if let type = yamlScalar(in: schemaBlock, key: "type") {
            if type == "array", let itemType = yamlScalar(in: yamlNestedBlock(in: schemaBlock, parent: "items"), key: "type") {
                return "[\(itemType)]"
            }
            return type
        }

        return yamlReference(in: schemaBlock)
    }

    private static func parseYAMLSchemaFields(from block: [YAMLLine]) -> [OpenAPISchemaField] {
        let propertiesBlock = yamlNestedBlock(in: block, parent: "properties")
        let propertyIndent = propertiesBlock
            .filter { $0.text.hasSuffix(":") }
            .map(\.indent)
            .min()
        let required = Set(yamlListValues(in: yamlNestedBlock(in: block, parent: "required")))
        var fields: [OpenAPISchemaField] = []

        for index in propertiesBlock.indices {
            let line = propertiesBlock[index]
            guard line.text.hasSuffix(":"), line.indent == propertyIndent else {
                continue
            }

            let name = String(line.text.dropLast()).unquoted()
            let nested = nestedLines(after: index, in: propertiesBlock, parentIndent: line.indent)
            fields.append(
                OpenAPISchemaField(
                    name: name,
                    type: yamlFieldType(in: nested),
                    isRequired: required.contains(name),
                    description: yamlScalar(in: nested, key: "description")
                )
            )
        }

        return fields
    }

    private static func yamlFieldType(in lines: [YAMLLine]) -> String {
        if let type = yamlScalar(in: lines, key: "type") {
            if type == "array", let itemType = yamlScalar(in: yamlNestedBlock(in: lines, parent: "items"), key: "type") {
                return "[\(itemType)]"
            }
            return type
        }

        return yamlReference(in: lines) ?? "object"
    }

    private static func yamlListValues(in lines: [YAMLLine]) -> [String] {
        lines.compactMap { line in
            guard line.text.hasPrefix("- ") else {
                return nil
            }
            return line.text.removingListMarker().unquoted()
        }
    }

    private static func scalarValue(from trimmedLine: String, key: String) -> String? {
        let prefix = "\(key):"
        guard trimmedLine.hasPrefix(prefix) else {
            return nil
        }

        return String(trimmedLine.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespaces)
            .unquoted()
    }
}

private struct YAMLLine {
    var indent: Int
    var text: String
}

private extension String {
    func unquoted() -> String {
        var value = self
        if value.count >= 2,
           let first = value.first,
           let last = value.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            value.removeFirst()
            value.removeLast()
        }
        return value
    }

    func removingListMarker() -> String {
        guard hasPrefix("- ") else {
            return self
        }
        return String(dropFirst(2))
    }
}

private extension Dictionary where Key == String, Value == Any {
    func dictionary(at key: String) -> [String: Any]? {
        self[key] as? [String: Any]
    }
}
