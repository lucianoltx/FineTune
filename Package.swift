// swift-tools-version: 6.2
// Build sem Xcode (só Command Line Tools): `swift build -c release`.
// Espelha as build settings do FineTune.xcodeproj (Swift 6, approachable concurrency, MemberImportVisibility, -D ENABLE_TCC_SPI). Assets.xcassets é
// substituído por recursos soltos no bundle montado por scripts/build-sem-xcode.sh.
import PackageDescription

let package = Package(
    name: "FineTune",
    platforms: [.macOS("15.4")],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/wadetregaskis/FluidMenuBarExtra", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "FineTune",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "FluidMenuBarExtra", package: "FluidMenuBarExtra"),
            ],
            path: "FineTune",
            exclude: ["Assets.xcassets", "Info.plist", "FineTune.entitlements"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .define("ENABLE_TCC_SPI"),
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
    ]
)
