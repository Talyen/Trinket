import Foundation
import os

public enum FramePacingSignpostSupport {
    public static let subsystem = "com.trinket.framepacing"

    public static func event(log: OSLog, name: StaticString, detail: String) {
        os_signpost(
            .event,
            log: log,
            name: name,
            "%{public}@",
            detail as NSString,
        )
    }
}
