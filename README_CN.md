# macOS video wallpaper app built with Swift
# SakuraWallpaper

macOS 轻量级视频和图片壁纸应用。
当前版本：`v1.0.1`

[English Documentation](README.md)

## 功能特性

- 将视频 (MP4, MOV, GIF) 或图片 (PNG, JPG, HEIC, WebP) 设置为桌面壁纸
- **系统桌面图同步**: 图片会直接同步为系统桌面图；视频会在壁纸切换、锁屏或屏保启动时抓取当前播放画面并同步到系统桌面图
- **轮播模式**: 选择整个文件夹，自动循环播放其中的壁纸
- **每屏独立配置**: 每个显示器可独立保存文件夹路径、播放列表、轮播间隔和随机状态
- **精确同步轮播**: 链接多个屏幕后，它们的轮播计时器将实现毫秒级精确同步切换
- **双重预览模式**: 设置窗口内置实时视频预览播放，并提供文件夹内容的动态缩略图网格
- **调度中心与多屏稳定性**: 壁纸无缝覆盖所有虚拟桌面空间，并在显示器重新连接时瞬间恢复
- **低电量自动暂停**: 当电池电量低于或等于 20% 且未充电时，自动暂停壁纸播放
- 多显示器支持与强大的屏幕识别机制
- 视频壁纸自动循环播放
- 最近使用历史，支持快速切换（支持文件夹历史）
- 开机自启动支持
- 手动暂停/恢复播放控制
- 中英文双语界面

## 截图

![主窗口](img/Sakurawallpaper1.jpeg)

![状态栏菜单](img/Sakurawallpaper2.jpeg)

![SakuraWallpaper Demo](img/video.gif)

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
或者
```
brew install --cask yueseqaz/tap/sakura-wallpaper
```

### 从源码构建

```
git clone https://github.com/yueseqaz/SakuraWallpaper.git
cd SakuraWallpaper
./build.sh
open build/SakuraWallpaper.app
```

要求: macOS 12.0+, Xcode Command Line Tools

## 使用方法

1. 在主预览区 **拖拽** 壁纸文件/文件夹，或 **点击预览区** 打开访达选择
2. 使用 **轮播间隔** 调节器设置壁纸更换频率（仅限轮播模式）
3. 开启 **随机轮播** 以打乱播放顺序
4. 开启 **省电模式**，在低电量时自动暂停壁纸
5. 使用屏幕下拉框切换不同显示器（内置显示器优先显示）
6. 勾选 **链接屏幕** 可将当前屏幕的配置和轮播时间与其他链接的屏幕保持同步
7. 点击 **停止壁纸** 清除当前屏幕的壁纸
8. 选择 **新屏幕策略** 以决定新连接的显示器如何自动配置（例如：继承同步组）
9. 右键状态栏图标可进行快速控制

### 系统桌面图同步说明

- 图片壁纸会立即同步到系统桌面图
- 视频壁纸会在切换壁纸时抓取当前播放帧并同步
- 锁屏或启动屏保时，会再次根据当前屏幕正在显示的内容刷新系统桌面图

### 省电模式说明

- 仅在“电量 `<=20%` 且未充电”时触发自动暂停
- 自动暂停与手动暂停是两种不同状态

### 状态栏菜单

- **打开 SakuraWallpaper** - 打开主窗口
- **状态: 正在运行/手动暂停/低电量自动暂停/无** - 实时状态显示
- **暂停** - 子菜单：支持“所有屏幕”与“按屏幕”暂停/恢复
- **省电模式** - 开启低电量自动暂停（<=20% 且未充电）
- **下一张壁纸** - 支持“所有屏幕”与“按屏幕切换下一张”（快捷键 `n` 作用于所有屏幕）
- **清除壁纸** - 重置并移除当前选择
- **最近使用** - 快速切换历史壁纸或文件夹
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
├── ThumbnailItem.swift        # 预览网格项
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
