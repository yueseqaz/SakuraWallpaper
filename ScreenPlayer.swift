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

    init(fileURL: URL, screen: NSScreen) {
        self.screen = screen
        self.fileURL = fileURL
        setupWindow()
        setupContent()
    }

    var mediaURL: URL { fileURL }

    func updateMedia(url: URL) {
        self.fileURL = url
        clearContent()
        setupContent()
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
        
        if let contentView = window?.contentView {
            contentView.layer = nil
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
        case .image: setupImageView()
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
        playerLayer?.videoGravity = .resizeAspectFill
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

    private func setupImageView() {
        guard let image = NSImage(contentsOf: fileURL),
              let contentView = window?.contentView else { return }

        let imageLayer = CALayer()
        imageLayer.contents = image
        imageLayer.frame = contentView.bounds
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        contentView.layer = imageLayer

        window?.orderBack(nil)
    }

    func resumePlayback() {
        guard let player = avPlayer else { return }
        let currentTime = player.currentTime()
        player.seek(to: currentTime) { [weak self] _ in
            self?.avPlayer?.play()
            self?.avPlayer?.rate = 1.0
        }
    }

    func pausePlayback() {
        avPlayer?.pause()
    }

    func restartPlayer() {
        avPlayer?.pause()
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        endObserver = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        avPlayer = nil
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
