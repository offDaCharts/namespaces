// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Namespaces",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Namespaces", targets: ["Namespaces"]),
        .library(name: "NamespacesCore", targets: ["NamespacesCore"]),
    ],
    targets: [
        .target(
            name: "NamespacesCore",
            path: "Sources/NamespacesCore"
        ),
        .executableTarget(
            name: "Namespaces",
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
