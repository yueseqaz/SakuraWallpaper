import Foundation

// MARK: - Screen_Config

struct Screen_Config: Codable, Equatable {
    var folderPath: String?
    var wallpaperPath: String?
    var rotationIntervalMinutes: Int
    var isShuffleMode: Bool
    var isRotationEnabled: Bool
    var includeSubfolders: Bool
    var isFolderMode: Bool
    var isSynced: Bool

    static let `default` = Screen_Config(
        folderPath: nil,
        wallpaperPath: nil,
        rotationIntervalMinutes: 15,
        isShuffleMode: false,
        isRotationEnabled: true,
        includeSubfolders: false,
        isFolderMode: false,
        isSynced: true
    )

    enum CodingKeys: String, CodingKey {
        case folderPath              = "folder_path"
        case wallpaperPath           = "wallpaper_path"
        case rotationIntervalMinutes = "rotation_interval_minutes"
        case isShuffleMode           = "is_shuffle_mode"
        case isRotationEnabled       = "is_rotation_enabled"
        case includeSubfolders       = "include_subfolders"
        case isFolderMode            = "is_folder_mode"
        case isSynced                = "is_synced"
    }

    init(
        folderPath: String?,
        wallpaperPath: String?,
        rotationIntervalMinutes: Int,
        isShuffleMode: Bool,
        isRotationEnabled: Bool,
        includeSubfolders: Bool,
        isFolderMode: Bool,
        isSynced: Bool
    ) {
        self.folderPath = folderPath
        self.wallpaperPath = wallpaperPath
        self.rotationIntervalMinutes = rotationIntervalMinutes
        self.isShuffleMode = isShuffleMode
        self.isRotationEnabled = isRotationEnabled
        self.includeSubfolders = includeSubfolders
        self.isFolderMode = isFolderMode
        self.isSynced = isSynced
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = Screen_Config.default
        folderPath              = try container.decodeIfPresent(String.self, forKey: .folderPath)              ?? d.folderPath
        wallpaperPath           = try container.decodeIfPresent(String.self, forKey: .wallpaperPath)           ?? d.wallpaperPath
        rotationIntervalMinutes = try container.decodeIfPresent(Int.self,    forKey: .rotationIntervalMinutes) ?? d.rotationIntervalMinutes
        isShuffleMode           = try container.decodeIfPresent(Bool.self,   forKey: .isShuffleMode)           ?? d.isShuffleMode
        isRotationEnabled       = try container.decodeIfPresent(Bool.self,   forKey: .isRotationEnabled)       ?? d.isRotationEnabled
        includeSubfolders       = try container.decodeIfPresent(Bool.self,   forKey: .includeSubfolders)       ?? d.includeSubfolders
        isFolderMode            = try container.decodeIfPresent(Bool.self,   forKey: .isFolderMode)            ?? d.isFolderMode
        isSynced                = try container.decodeIfPresent(Bool.self,   forKey: .isSynced)                ?? d.isSynced
    }
}

// MARK: - Screen_Registry

typealias Screen_Registry = [String: Screen_Config]

// MARK: - New_Screen_Policy

enum New_Screen_Policy: String, Codable {
    case inheritSyncGroup
    case blank
}
