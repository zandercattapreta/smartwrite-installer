// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartWriteInstaller",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SmartWriteInstaller",
            path: "Sources/SmartWriteInstaller",
            exclude: ["Info.plist", "SmartWriteInstaller.entitlements"],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
