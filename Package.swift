// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DesktopCompanion",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DesktopCompanion", targets: ["DesktopCompanion"])
    ],
    targets: [
        .executableTarget(
            name: "DesktopCompanion",
            path: "Sources/DesktopCompanion",
            resources: [
                .process("Resources/companion.svg"),
                .copy("Resources/Companions"),
                .copy("Resources/ConversationThemes")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "DesktopCompanionTests",
            dependencies: ["DesktopCompanion"]
        )
    ]
)
