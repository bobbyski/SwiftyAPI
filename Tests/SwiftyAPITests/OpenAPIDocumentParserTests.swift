import Testing
@testable import SwiftyAPI

@Test
func parsesJSONSummaryAndOperations() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalJSON, format: .json)

    #expect(document.summary.openAPIVersion == "3.1.0")
    #expect(document.summary.title == "Example API")
    #expect(document.summary.operations.count == 1)
    #expect(document.summary.operations.first?.id == "GET /pets")
}

@Test
func parsesYAMLSummaryAndOperations() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalYAML, format: .yaml)

    #expect(document.summary.openAPIVersion == "3.1.0")
    #expect(document.summary.servers == ["https://api.example.com"])
    #expect(document.summary.operations.map(\.id) == ["GET /pets", "POST /pets"])
}

@Test
func generatorCreatesSwiftCases() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalYAML, format: .yaml)
    let generated = SwiftEndpointGenerator.generate(document: document)

    #expect(generated.contains("public enum ExampleAPIEndpoint"))
    #expect(generated.contains("case listPets = \"GET /pets\""))
    #expect(generated.contains("case createPet = \"POST /pets\""))
}
