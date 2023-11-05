// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "HandyMacros",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .visionOS(.v1), .macCatalyst(.v13)],
    products: [
        .library(
            name: "HandyMacros",
            targets: ["HandyMacros"]
        ),
        .executable(
            name: "HandyMacrosClient",
            targets: ["HandyMacrosClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.2"),
    ],
    targets: [
        .macro(
            name: "HandyMacrosExternal",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(name: "HandyMacros", dependencies: ["HandyMacrosExternal"]),
        .executableTarget(name: "HandyMacrosClient", dependencies: ["HandyMacros"]),
        .testTarget(
            name: "HandyMacrosTests",
            dependencies: [
                "HandyMacrosExternal",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
