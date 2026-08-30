// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Clip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Clip", targets: ["Clip"])
    ],
    targets: [
        .executableTarget(
            name: "Clip",
            path: "Sources/Clip",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Vision"),
                .linkedFramework("QuickLookUI"),
            ]
        )
    ]
)
