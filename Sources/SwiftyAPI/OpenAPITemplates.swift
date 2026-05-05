public enum OpenAPITemplates {
    public static let minimalYAML = """
    openapi: 3.1.0
    info:
      title: Example API
      version: 1.0.0
    servers:
      - url: https://api.example.com
    paths:
      /pets:
        get:
          operationId: listPets
          summary: List pets
          responses:
            '200':
              description: OK
        post:
          operationId: createPet
          summary: Create a pet
          responses:
            '201':
              description: Created
    """

    public static let minimalJSON = """
    {
      "openapi": "3.1.0",
      "info": {
        "title": "Example API",
        "version": "1.0.0"
      },
      "servers": [
        { "url": "https://api.example.com" }
      ],
      "paths": {
        "/pets": {
          "get": {
            "operationId": "listPets",
            "summary": "List pets",
            "responses": {
              "200": {
                "description": "OK"
              }
            }
          }
        }
      }
    }
    """
}
