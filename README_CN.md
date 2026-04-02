# macOS video wallpaper app built with Swift
# SakuraWallpaper

macOS 轻量级视频和图片壁纸应用。

[English Documentation](README.md)

## 功能特性

- 将视频 (MP4, MOV, GIF) 或图片 (PNG, JPG, HEIC, WebP) 设置为桌面壁纸
- 多显示器支持，可为每个屏幕设置独立壁纸
- 视频壁纸自动循环播放
- 最近使用壁纸历史，快速切换
- 开机自启动支持
- 暂停和恢复壁纸播放
- 中英文双语界面

## 截图

![主窗口](img/Sakurawallpaper1.jpeg)

![状态栏菜单](img/Sakurawallpaper2.jpeg)
## 🎬 Preview

![SakuraWallpaper Demo](img/video.gif)

👉 Full demo video: https://youtu.be/xxxx

## 支持格式

**视频**
- MP4, MOV, M4V
- GIF (动态)

**图片**
- PNG, JPG, JPEG
- HEIC
- WebP, BMP, TIFF

## 安装

### 下载安装

从 [Releases](../../releases) 下载最新的 `SakuraWallpaper.dmg`，将 SakuraWallpaper 拖入应用程序文件夹。

### 从源码构建

```
git clone https://github.com/yueseqaz/SakuraWallpaper.git
cd SakuraWallpaper
./build.sh
open build/SakuraWallpaper.app
```

要求: macOS 12.0+, Xcode Command Line Tools

## 使用方法

1. 点击 **选择壁纸** 选择视频或图片文件
2. 使用屏幕下拉框切换不同显示器
3. 点击 **应用到全部** 将同一壁纸设置到所有屏幕
4. 点击 **停止壁纸** 移除选中屏幕的壁纸
5. 右键状态栏图标查看更多选项

### 状态栏菜单

- **打开樱花壁纸** - 打开主窗口
- **全部暂停** - 暂停/恢复所有壁纸
- **暂停屏幕** - 暂停/恢复单个屏幕
- **最近使用** - 快速切换历史壁纸
- **语言** - 切换中英文界面
- **清除历史** - 清除壁纸历史记录

## 修复"应用已损坏"提示

如果打开时提示"SakuraWallpaper 已损坏，无法打开"，请在终端执行：

```
xattr -cr /Applications/SakuraWallpaper.app
```

这会移除 macOS 为网络下载应用添加的隔离属性。

## 系统要求

- macOS 12.0 Monterey 或更高版本
- 支持多显示器

## 项目结构

```
SakuraWallpaper/
├── AppDelegate.swift          # 应用生命周期和状态栏
├── MainWindowController.swift # 主窗口界面
├── WallpaperManager.swift     # 壁纸播放引擎
├── ScreenPlayer.swift         # 单屏幕播放器
├── SettingsManager.swift      # 用户偏好设置存储
├── Localization.swift         # 本地化辅助
├── MediaType.swift            # 文件类型检测
├── AboutWindowController.swift # 关于窗口
├── main.swift                 # 入口文件
├── build.sh                   # 构建脚本
├── AppIcon.icns               # 应用图标
├── Resources/
│   ├── en.lproj/              # 英文字符串
│   └── zh-Hans.lproj/         # 中文字符串
├── README.md                  # 英文文档
├── README_CN.md               # 中文文档
├── LICENSE                    # MIT 许可证
└── .gitignore                 # Git 忽略规则
```

## 参与贡献

欢迎贡献代码。请提交 Issue 或 Pull Request。

## 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 致谢

由 sakura 制作
