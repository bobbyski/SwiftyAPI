import Foundation
import SwiftyAPI

@main
struct SwiftyAPIGeneratorCommand {
    static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()

        guard let inputPath = arguments.first else {
            print("Usage: swiftyapi-generate <openapi.json|openapi.yml|openapi.yaml>")
            throw ExitCode.failure
        }

        let source = try String(contentsOfFile: inputPath, encoding: .utf8)
        let format = OpenAPIFormat.infer(from: inputPath)
        let document = try OpenAPIDocument(source: source, format: format)
        print(SwiftEndpointGenerator.generate(document: document))
    }
}

enum ExitCode: Error {
    case failure
}
