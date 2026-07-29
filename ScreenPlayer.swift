import Cocoa
import AVKit
import AVFoundation

class ScreenPlayer {
    var window: NSWindow?
    private var avPlayer: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var imageView: NSImageView?
    private var endObserver: Any?
    private let screen: NSScreen
    private var fileURL: URL
    private var fitMode: WallpaperFitMode
    private var shouldResumeAfterSpaceTransition = false

    init(fileURL: URL, screen: NSScreen, fitMode: WallpaperFitMode) {
        self.screen = screen
        self.fileURL = fileURL
        self.fitMode = fitMode
        setupWindow()
        setupContent()
    }

    var mediaURL: URL { fileURL }
    var videoPlayer: AVPlayer? { avPlayer }

    func updateMedia(url: URL) {
        self.fileURL = url
        clearContent()
        setupContent()
    }

    func updateFitMode(_ fitMode: WallpaperFitMode) {
        self.fitMode = fitMode
        playerLayer?.videoGravity = fitMode.avLayerVideoGravity
        layoutImageView()
    }

    /// Resizes the player window and all its layers to match the current screen geometry.
    /// Called by WallpaperManager when a screen is reattached at a different resolution (Bug 1 fix),
    /// or when display arrangement changes cause an existing screen's frame to shift.
    func resize(to screen: NSScreen) {
        let newFrame = screen.frame
        let newSize = newFrame.size
        let newBounds = NSRect(origin: .zero, size: newSize)

        // Use display: true so the window redraws immediately at the new frame.
        window?.setFrame(newFrame, display: true)
        window?.contentView?.frame = newBounds

        if let layer = window?.contentView?.layer {
            layer.frame = newBounds
        }
        playerLayer?.frame = newBounds
        layoutImageView()
    }

    func currentPlaybackTime() -> CMTime? {
        guard MediaType.detect(fileURL) == .video else { return nil }
        let time = avPlayer?.currentTime() ?? .zero
        let seconds = time.seconds
        guard time.isValid, seconds.isFinite, seconds >= 0 else { return nil }
        return time
    }

    private func clearContent() {
        avPlayer?.pause()
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        endObserver = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        avPlayer = nil
        imageView?.removeFromSuperview()
        imageView = nil
        
        if let contentView = window?.contentView {
            contentView.layer = nil
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.black.cgColor
            contentView.layer?.masksToBounds = true
        }
    }

    private func setupWindow() {
        let screenFrame = screen.frame
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: screenFrame.size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        guard let window = window else { return }
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(origin: .zero, size: screenFrame.size))
        contentView.wantsLayer = true
        contentView.autoresizingMask = [.width, .height]
        contentView.layer?.backgroundColor = NSColor.black.cgColor
        window.contentView = contentView
    }

    private func setupContent() {
        switch MediaType.detect(fileURL) {
        case .video: setupVideoPlayer()
        case .gif: setupImageView(animated: true)
        case .image: setupImageView(animated: false)
        case .unsupported: break
        }
    }

    private func setupVideoPlayer() {
        let item = AVPlayerItem(asset: AVURLAsset(url: fileURL))
        avPlayer = AVPlayer(playerItem: item)
        avPlayer?.isMuted = true
        avPlayer?.volume = 0
        avPlayer?.automaticallyWaitsToMinimizeStalling = false
        avPlayer?.preventsDisplaySleepDuringVideoPlayback = false

        playerLayer = AVPlayerLayer(player: avPlayer)
        playerLayer?.videoGravity = fitMode.avLayerVideoGravity
        playerLayer?.backgroundColor = NSColor.black.cgColor

        if let contentView = window?.contentView {
            playerLayer?.frame = contentView.bounds
            contentView.layer = playerLayer
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.avPlayer?.seek(to: .zero)
            self?.avPlayer?.play()
        }

        window?.orderBack(nil)
        avPlayer?.play()
    }

    private func setupImageView(animated: Bool) {
        guard let image = NSImage(contentsOf: fileURL),
              let contentView = window?.contentView else { return }

        let imageView = NSImageView(frame: contentView.bounds)
        imageView.image = image
        imageView.animates = animated
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleAxesIndependently
        contentView.addSubview(imageView)
        self.imageView = imageView
        layoutImageView()

        window?.orderBack(nil)
    }

    private func layoutImageView() {
        guard let imageView,
              let contentView = window?.contentView,
              let image = imageView.image else { return }

        let bounds = contentView.bounds
        let imageSize = image.size
        guard bounds.width > 0, bounds.height > 0, imageSize.width > 0, imageSize.height > 0 else {
            imageView.frame = bounds
            return
        }

        switch fitMode {
        case .stretch:
            imageView.frame = bounds
        case .fit:
            imageView.frame = aspectRect(for: imageSize, in: bounds, fill: false)
        case .fill:
            imageView.frame = aspectRect(for: imageSize, in: bounds, fill: true)
        }
    }

    private func aspectRect(for imageSize: NSSize, in bounds: NSRect, fill: Bool) -> NSRect {
        let widthRatio = bounds.width / imageSize.width
        let heightRatio = bounds.height / imageSize.height
        let scale = fill ? max(widthRatio, heightRatio) : min(widthRatio, heightRatio)
        let fittedSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return NSRect(
            x: bounds.midX - (fittedSize.width / 2),
            y: bounds.midY - (fittedSize.height / 2),
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    func resumePlayback() {
        guard let player = avPlayer else { return }
        shouldResumeAfterSpaceTransition = false
        guard player.timeControlStatus != .playing else { return }
        player.playImmediately(atRate: 1.0)
    }

    func pausePlayback() {
        shouldResumeAfterSpaceTransition = false
        avPlayer?.pause()
    }

    func beginSpaceTransition() {
        guard let player = avPlayer else { return }
        if player.timeControlStatus != .paused {
            shouldResumeAfterSpaceTransition = true
        }
    }

    func endSpaceTransition() {
        guard shouldResumeAfterSpaceTransition, let player = avPlayer else { return }
        shouldResumeAfterSpaceTransition = false

        // Toggling the timebase wakes rendering without clearing the displayed frame.
        player.pause()
        player.playImmediately(atRate: 1.0)
    }

    func restartPlayer() {
        avPlayer?.pause()
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        endObserver = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        avPlayer = nil
        imageView?.removeFromSuperview()
        imageView = nil
        setupVideoPlayer()
    }

    func cleanup() {
        avPlayer?.pause()
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        endObserver = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        avPlayer = nil
        imageView?.removeFromSuperview()
        imageView = nil
        window?.orderOut(nil)
        window = nil
    }

    deinit { cleanup() }
}

private extension WallpaperFitMode {
    var avLayerVideoGravity: AVLayerVideoGravity {
        switch self {
        case .fill:
            return .resizeAspectFill
        case .fit:
            return .resizeAspect
        case .stretch:
            return .resize
        }
    }
}
