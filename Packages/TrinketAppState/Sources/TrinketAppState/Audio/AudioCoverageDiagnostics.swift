#if DEBUG
import Darwin
import Foundation
import Synchronization

/// Debug observations of real backends. The app probe is the only external
/// consumer; these counts do not establish audible output or device budgets.
public enum AudioCoverageDiagnostics {
    private struct Observations {
        var sfxPlays = 0
        var sfxStarts = 0
        var musicStarts = 0
        var audioFailures = 0
        var duplicateMusicOwners = 0
        var activeMusic: [UUID: String] = [:]
    }

    private static let observations = Mutex(Observations())
    static let enabled = ProcessInfo.processInfo.arguments.contains("-coverage-diagnostics")
        && ProcessInfo.processInfo.arguments.contains("-store-name")

    static func sfxStarted() {
        guard enabled else { return }
        observations.withLock { $0.sfxStarts += 1 }
    }

    static func sfxPlayed() {
        guard enabled else { return }
        observations.withLock { $0.sfxPlays += 1 }
    }

    static func failed() {
        guard enabled else { return }
        observations.withLock { $0.audioFailures += 1 }
    }

    static func musicStarted(id: UUID, track: String) {
        guard enabled else { return }
        observations.withLock { value in
            guard value.activeMusic[id] == nil else { return }
            if value.activeMusic.values.contains(track) {
                value.duplicateMusicOwners += 1
            }
            value.activeMusic[id] = track
            value.musicStarts += 1
        }
    }

    static func musicStopped(id: UUID) {
        guard enabled else { return }
        observations.withLock { $0.activeMusic.removeValue(forKey: id) }
    }

    public static func snapshot() -> [String: Int] {
        var result = observations.withLock { value in
            ["sfxPlays": value.sfxPlays, "sfxStarts": value.sfxStarts,
             "musicStarts": value.musicStarts, "audioFailures": value.audioFailures,
             "duplicateMusicOwners": value.duplicateMusicOwners, "activeMusic": value.activeMusic.count]
        }
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if status == KERN_SUCCESS {
            result["physicalFootprintBytes"] = Int(info.phys_footprint)
        }
        return result
    }
}
#endif
