// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScrollTabView",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "ScrollTabView",
            targets: ["ScrollTabView"]),
    ],
    dependencies: [
        .package(url: "https://github.com/quentinfasquel/ScrollViewEvents", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "ScrollTabView",
            dependencies: ["ScrollViewEvents"])
    ]
)
