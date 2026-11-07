// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BookflowCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "BookflowCore", targets: ["BookflowCore"])],
    targets: [
        .target(
            name: "BookflowCore",
            path: "BookFlowApp/BookFlowApp",
            exclude: ["App/BookflowApp.swift", "App/RootView.swift", "Assets.xcassets", "Core/UI", "Features", "PreviewSupport"],
            sources: ["App/AppEnvironment.swift", "Core/Models", "Mocks", "Services"]
        ),
        .testTarget(name: "BookflowCoreTests", dependencies: ["BookflowCore"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
