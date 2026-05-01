// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "openidconnect_darwin",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15")
    ],
    products: [
        .library(name: "openidconnect-darwin", targets: ["openidconnect_darwin"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "openidconnect_darwin",
            dependencies: [],
            resources: []
        )
    ]
)
