// swift-tools-version:5.9
import PackageDescription

// The mixing engine as a plain Swift package so it can be tested with `swift test`
// on any platform. The iOS app (ColorMatch.xcodeproj) compiles these same sources.
let package = Package(
    name: "ColorMixCore",
    products: [
        .library(name: "ColorMixCore", targets: ["ColorMixCore"]),
    ],
    targets: [
        .target(name: "ColorMixCore"),
        .testTarget(name: "ColorMixCoreTests", dependencies: ["ColorMixCore"]),
    ]
)
