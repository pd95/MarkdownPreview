// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RenderFixtures",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../../MarkdownPipeline")
    ],
    targets: [
        .executableTarget(
            name: "RenderFixtures",
            dependencies: ["MarkdownPipeline"]
        )
    ]
)
