import TrinketFeatureSupport
import XCTest

extension TrinketUITestCase {
    func auditProductAccessibility(screen: String) throws {
        let originalContinueAfterFailure = continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = originalContinueAfterFailure }
        let application = try XCTUnwrap(app)
        let auditType = Self.self
        try trinketOnMainActor {
            let types: [(String, XCUIAccessibilityAuditType)] = [
                ("contrast", .contrast), ("element-detection", .elementDetection), ("hit-region", .hitRegion),
                ("description", .sufficientElementDescription), ("dynamic-type", .dynamicType),
                ("text-clipped", .textClipped), ("trait", .trait),
            ]
            for (name, type) in types {
                do {
                    try auditType.performProductAudit(application, screen: screen, name: name, type: type, attempt: 1)
                } catch let error as NSError where error.domain == "com.apple.xcode.xctest.accessibilityAudit" && error.code == -56 {
                    // Retry one native audit timeout; violations and a second timeout still fail.
                    try auditType.performProductAudit(application, screen: screen, name: name, type: type, attempt: 2)
                }
            }
        }
    }

    @MainActor private static func performProductAudit(
        _ application: XCUIApplication, screen: String, name: String, type: XCUIAccessibilityAuditType, attempt: Int,
    ) throws {
        try XCTContext.runActivity(named: "Accessibility: \(screen)/\(name), attempt \(attempt)") { activity in
            let environment = ProcessInfo.processInfo.environment
            let context = "Screen: \(screen)\nAudit: \(name)\nAttempt: \(attempt)\n"
                + "Profile: \(environment["TRINKET_PROFILE_NAME"] ?? "unspecified")\n"
                + "Runtime: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
                + "Requested large text: \(environment["TRINKET_PROFILE_LARGE_TEXT"] ?? "0")\n"
                + "Requested Reduce Motion: \(environment["TRINKET_PROFILE_REDUCE_MOTION"] ?? "0")"
            let identity = XCTAttachment(string: context)
            identity.name = "audit-context"
            identity.lifetime = .keepAlways
            activity.add(identity)
            var hadFailure = false
            defer {
                // Capture once after the native audit releases its snapshot work.
                if hadFailure, application.state == .runningForeground {
                    let screenshot = XCTAttachment(screenshot: application.screenshot())
                    screenshot.name = "\(screen)-\(name)"
                    screenshot.lifetime = .keepAlways
                    activity.add(screenshot)
                }
            }
            @MainActor func retainFailure(_ detail: String) {
                hadFailure = true
                let attachment = XCTAttachment(string: context + "\n" + detail)
                attachment.name = "audit-failure"
                attachment.lifetime = .keepAlways
                activity.add(attachment)
            }
            do {
                try application.performAccessibilityAudit(for: type) { issue in
                    if issue.element?.identifier == AccessibilityID.Debug.coverageDiagnostics {
                        return true
                    }
                    retainFailure("\(issue.compactDescription)\n\(issue.detailedDescription)\n"
                        + String((issue.element?.debugDescription ?? "No element").prefix(3000)))
                    return false
                }
            } catch {
                retainFailure(String(describing: error))
                throw error
            }
        }
    }
}
