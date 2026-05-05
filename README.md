# SwiftyAPI

SwiftyAPI is a SwiftUI framework for embedding an OpenAPI/Swagger editor in a macOS or iOS app.

## Targets

- `SwiftyAPI`: reusable SwiftUI framework.
- `SwiftyAPIDemo`: minimal SwiftUI demo app.
- `swiftyapi-generate`: command-line generator that reads `.json`, `.yaml`, or `.yml` OpenAPI files and emits Swift endpoint cases.

## Quick Start

```swift
import SwiftUI
import SwiftyAPI

struct ContentView: View {
    var body: some View {
        SwiftyAPIView()
    }
}
```

For document-based apps, use `OpenAPIFile` with SwiftUI `DocumentGroup` and pass its `source` and `format` into your editor flow.

## Commands

```bash
swift build
swift test
swift run swiftyapi-generate path/to/openapi.yaml
swift run SwiftyAPIDemo
```
