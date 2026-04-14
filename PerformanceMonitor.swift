import Foundation
import Darwin.Mach

final class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private var startTimes: [UUID: (label: String, start: CFAbsoluteTime)] = [:]
    private let queue = DispatchQueue(label: "com.sakura.wallpaper.performance")
    private var peakMemoryMB: Double = 0

    private init() {}

    @discardableResult
    func begin(_ label: String) -> UUID {
        let token = UUID()
        let now = CFAbsoluteTimeGetCurrent()
        queue.sync {
            startTimes[token] = (label, now)
        }
        return token
    }

    func end(_ token: UUID, extra: String = "") {
        let result: (String, Double)? = queue.sync {
            guard let item = startTimes.removeValue(forKey: token) else { return nil }
            let elapsed = (CFAbsoluteTimeGetCurrent() - item.start) * 1000
            return (item.label, elapsed)
        }
        guard let (label, elapsedMs) = result else { return }
        updateMemoryPeak()
        let memory = String(format: "%.1f", peakMemoryMB)
        let duration = String(format: "%.2f", elapsedMs)
        if extra.isEmpty {
            print("[Perf] \(label): \(duration)ms | peakRSS=\(memory)MB")
        } else {
            print("[Perf] \(label): \(duration)ms | peakRSS=\(memory)MB | \(extra)")
        }
    }

    private func updateMemoryPeak() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let rssMB = Double(info.resident_size) / (1024 * 1024)
        if rssMB > peakMemoryMB {
            peakMemoryMB = rssMB
        }
    }
}
