import Foundation

public enum OpenAPIFormatTranslator {
    public static func convert(source: String, from currentFormat: OpenAPIFormat, to targetFormat: OpenAPIFormat) throws -> String {
        guard currentFormat != targetFormat else {
            return source
        }

        switch (currentFormat, targetFormat) {
        case (.json, .yaml):
            return try jsonToYAML(source)
        case (.yaml, .json):
            return try yamlToJSON(source)
        case (.json, .json), (.yaml, .yaml):
            return source
        }
    }

    public static func inferFormat(from source: String, fallback: OpenAPIFormat) -> OpenAPIFormat {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return fallback
        }

        if trimmed.first == "{" || trimmed.first == "[" {
            return .json
        }

        if (try? OpenAPIDocument(source: source, format: .json)) != nil {
            return .json
        }

        return .yaml
    }

    private static func jsonToYAML(_ source: String) throws -> String {
        do {
            let data = Data(source.utf8)
            let object = try JSONSerialization.jsonObject(with: data)
            return renderYAML(object, indent: 0)
        } catch {
            throw OpenAPIParseError.invalidJSON(error.localizedDescription)
        }
    }

    private static func yamlToJSON(_ source: String) throws -> String {
        let document = try OpenAPIDocument(source: source, format: .yaml)
        let object = jsonObject(from: document.summary)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private static func jsonObject(from summary: OpenAPISummary) -> [String: Any] {
        var paths: [String: Any] = [:]

        for operation in summary.operations {
            var operationObject: [String: Any] = [
                "responses": [
                    "200": [
                        "description": "OK"
                    ]
                ]
            ]

            if let operationID = operation.operationID {
                operationObject["operationId"] = operationID
            }

            if let summary = operation.summary {
                operationObject["summary"] = summary
            }

            var pathObject = paths[operation.path] as? [String: Any] ?? [:]
            pathObject[operation.method.rawValue] = operationObject
            paths[operation.path] = pathObject
        }

        var object: [String: Any] = [
            "openapi": summary.openAPIVersion,
            "info": [
                "title": summary.title,
                "version": summary.version
            ],
            "paths": paths
        ]

        if summary.servers.isEmpty == false {
            object["servers"] = summary.servers.map { ["url": $0] }
        }

        return object
    }

    private static func renderYAML(_ value: Any, indent: Int) -> String {
        let spaces = String(repeating: " ", count: indent)

        if let dictionary = value as? [String: Any] {
            return dictionary.keys.sorted().map { key in
                let nestedValue = dictionary[key] as Any
                if isScalar(nestedValue) {
                    return "\(spaces)\(key): \(renderScalar(nestedValue))"
                }
                return "\(spaces)\(key):\n\(renderYAML(nestedValue, indent: indent + 2))"
            }.joined(separator: "\n")
        }

        if let array = value as? [Any] {
            return array.map { item in
                if isScalar(item) {
                    return "\(spaces)- \(renderScalar(item))"
                }

                let nested = renderYAML(item, indent: indent + 2)
                return "\(spaces)-\n\(nested)"
            }.joined(separator: "\n")
        }

        return "\(spaces)\(renderScalar(value))"
    }

    private static func isScalar(_ value: Any) -> Bool {
        value is String || value is NSNumber || value is NSNull
    }

    private static func renderScalar(_ value: Any) -> String {
        if value is NSNull {
            return "null"
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        if let string = value as? String {
            if string.isEmpty {
                return "\"\""
            }

            if string.rangeOfCharacter(from: CharacterSet(charactersIn: ":#{}[],'\"").union(.newlines)) != nil {
                return "\"\(string.replacingOccurrences(of: "\"", with: "\\\""))\""
            }

            return string
        }

        return "\(value)"
    }
}
