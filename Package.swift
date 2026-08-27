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
            dependencies: [
                "NamespacesCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Namespaces",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(
            name: "NamespacesCoreTests",
            dependencies: ["NamespacesCore"],
            path: "Tests/NamespacesCoreTests"
        ),
    ]
)
