// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Namespaces",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Namespaces", targets: ["Namespaces"]),
        .library(name: "NamespacesCore", targets: ["NamespacesCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6"),
    ],
    targets: [
        .target(
            name: "NamespacesCore",
            path: "Sources/NamespacesCore"
        ),
        .executableTarget(
            name: "Namespaces",
            // Sparkle remains a release-time appcast generator only. It is not
            // linked or embedded in the application bundle.
            dependencies: ["NamespacesCore"],
            path: "Sources/Namespaces",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "NamespacesCoreTests",
            dependencies: ["NamespacesCore"],
            path: "Tests/NamespacesCoreTests"
        ),
    ]
)
