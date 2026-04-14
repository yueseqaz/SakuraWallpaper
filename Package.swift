// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SakuraWallpaperCore",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "SakuraWallpaperCore", targets: ["SakuraWallpaperCore"])
    ],
    targets: [
        .target(
            name: "SakuraWallpaperCore",
            path: ".",
            exclude: [
                "Resources",
                "img",
                "build",
                "docs",
                "Tests",
                "AppDelegate.swift",
                "MainWindowController.swift",
                "ScreenPlayer.swift",
                "WallpaperManager.swift",
                "ThumbnailItem.swift",
                "ThumbnailProvider.swift",
                "Localization.swift",
                "PerformanceMonitor.swift",
                "AboutWindowController.swift",
                "main.swift",
                "AppIcon.icns",
                "bg.jpg",
                "README.md",
                "README_CN.md",
                "LICENSE",
                "build.sh"
            ],
            sources: [
                "SettingsManager.swift",
                "MediaType.swift",
                "PlaylistBuilder.swift"
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "SakuraWallpaperCoreTests",
            dependencies: ["SakuraWallpaperCore"],
            path: "Tests/SakuraWallpaperCoreTests"
        )
    ]
)
