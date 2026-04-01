import Cocoa
import AVKit
import AVFoundation
import ServiceManagement

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
