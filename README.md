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

For the current diagnostic editor, use `SwiftyAPIDebugView`. The public `SwiftyAPIView` is intentionally minimal while the main interaction model is being designed.

## Commands

```bash
swift build
swift test
swift run swiftyapi-generate path/to/openapi.yaml
swift run SwiftyAPIDemo
xcodegen generate
xcodebuild -project SwiftyAPI.xcodeproj -scheme SwiftyAPIDemo -destination platform=macOS build
```

The generated Xcode project is configured for local macOS runs with ad-hoc signing (`CODE_SIGN_IDENTITY = -`), so it should build and run from Xcode without requiring a paid developer team or command-line signing overrides.
