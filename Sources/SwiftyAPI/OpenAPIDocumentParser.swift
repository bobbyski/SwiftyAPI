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

            return OpenAPISummary(
                openAPIVersion: openAPIVersion,
                title: info?["title"] as? String ?? "Untitled API",
                version: info?["version"] as? String ?? "0.0.0",
                servers: servers,
                operations: parseJSONOperations(paths: paths)
            )
        } catch let parseError as OpenAPIParseError {
            throw parseError
        } catch {
            throw OpenAPIParseError.invalidJSON(error.localizedDescription)
        }
    }

    private static func parseJSONOperations(paths: [String: Any]) -> [OpenAPIOperation] {
        var operations: [OpenAPIOperation] = []

        for path in paths.keys.sorted() {
            guard let pathObject = paths[path] as? [String: Any] else {
                continue
            }

            for method in OpenAPIHTTPMethod.allCases where pathObject[method.rawValue] != nil {
                let operationObject = pathObject[method.rawValue] as? [String: Any]
                operations.append(
                    OpenAPIOperation(
                        method: method,
                        path: path,
                        operationID: operationObject?["operationId"] as? String,
                        summary: operationObject?["summary"] as? String
                    )
                )
            }
        }

        return operations
    }

    private static func parseYAML(_ source: String) throws -> OpenAPISummary {
        let lines = source.components(separatedBy: .newlines)
        let openAPIVersion = firstScalar(in: lines, keys: ["openapi", "swagger"])

        guard let openAPIVersion else {
            throw OpenAPIParseError.missingOpenAPIVersion
        }

        return OpenAPISummary(
            openAPIVersion: openAPIVersion,
            title: nestedScalar(in: lines, parent: "info", child: "title") ?? "Untitled API",
            version: nestedScalar(in: lines, parent: "info", child: "version") ?? "0.0.0",
            servers: yamlServers(in: lines),
            operations: yamlOperations(in: lines)
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

    private static func yamlOperations(in lines: [String]) -> [OpenAPIOperation] {
        var operations: [OpenAPIOperation] = []
        var isInsidePaths = false
        var currentPath: String?
        var currentMethod: OpenAPIHTTPMethod?
        var currentOperationID: String?
        var currentSummary: String?

        func flush() {
            guard let path = currentPath, let method = currentMethod else {
                return
            }
            operations.append(
                OpenAPIOperation(
                    method: method,
                    path: path,
                    operationID: currentOperationID,
                    summary: currentSummary
                )
            )
            currentMethod = nil
            currentOperationID = nil
            currentSummary = nil
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
                continue
            }

            if indent >= 6 {
                if let value = scalarValue(from: trimmed, key: "operationId") {
                    currentOperationID = value
                }
                if let value = scalarValue(from: trimmed, key: "summary") {
                    currentSummary = value
                }
            }
        }

        flush()
        return operations
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
}
