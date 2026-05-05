// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftyAPI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SwiftyAPI",
            targets: ["SwiftyAPI"]
        ),
        .executable(
            name: "SwiftyAPIDemo",
            targets: ["SwiftyAPIDemo"]
        ),
        .executable(
            name: "swiftyapi-generate",
            targets: ["SwiftyAPIGenerator"]
        )
    ],
    targets: [
        .target(
            name: "SwiftyAPI"
        ),
        .executableTarget(
            name: "SwiftyAPIDemo",
            dependencies: ["SwiftyAPI"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "SwiftyAPIGenerator",
            dependencies: ["SwiftyAPI"]
        ),
        .testTarget(
            name: "SwiftyAPITests",
            dependencies: ["SwiftyAPI"]
        )
    ]
)
