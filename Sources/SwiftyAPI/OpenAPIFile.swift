import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    static let openAPIYAML = UTType(filenameExtension: "yaml", conformingTo: .text)!
    static let openAPIYML = UTType(filenameExtension: "yml", conformingTo: .text)!
}

public struct OpenAPIFile: FileDocument, Sendable {
    public static var readableContentTypes: [UTType] {
        [.json, .openAPIYAML, .openAPIYML]
    }

    public static var writableContentTypes: [UTType] {
        readableContentTypes
    }

    public var source: String
    public var format: OpenAPIFormat

    public init(source: String = OpenAPITemplates.minimalYAML, format: OpenAPIFormat = .yaml) {
        self.source = source
        self.format = format
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let source = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.source = source

        if configuration.contentType == .json {
            self.format = .json
        } else {
            self.format = .yaml
        }
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(source.utf8))
    }

    public func parsedDocument() throws -> OpenAPIDocument {
        try OpenAPIDocument(source: source, format: format)
    }
}
