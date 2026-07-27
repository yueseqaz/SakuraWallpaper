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
                "AboutWindowController.swift",
                "main.swift",
                "AppIcon.icns",
                "bg.jpg",
                "README.md",
                "README_CN.md",
                "LICENSE",
                "build.sh",
                "reset.sh",
                "SakuraWallpaper.dmg",
                "SakuraWallpaper.entitlements",
                "Sources"
            ],
            sources: [
                "Screen_Config.swift",
                "SettingsManager.swift",
                "WallpaperBehavior.swift",
                "MediaType.swift",
                "PlaylistBuilder.swift",
                "AsyncWorkLimiter.swift",
                "Localization.swift",
                "PerformanceMonitor.swift",
                "ScreenPlayer.swift",
                "WallpaperManager.swift",
                "ThumbnailItem.swift",
                "ThumbnailProvider.swift"
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("AVKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ImageIO"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "SakuraWallpaperCoreTests",
            dependencies: ["SakuraWallpaperCore"],
            path: "Tests/SakuraWallpaperCoreTests"
        )
    ]
)
