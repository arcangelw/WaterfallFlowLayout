// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WaterfallFlowLayout",
    platforms: [
        .iOS(.v11),
    ],
    products: [
        .library(name: "WaterfallFlowLayout", targets: ["WaterfallFlowLayout"]),
    ],
    targets: [
        .target(
            name: "WaterfallFlowLayout",
            dependencies: []
        ),
        .testTarget(
            name: "WaterfallFlowLayoutTests",
            dependencies: ["WaterfallFlowLayout"]
        ),
    ],
    swiftLanguageVersions: [
        .version("5"),
    ]
)
