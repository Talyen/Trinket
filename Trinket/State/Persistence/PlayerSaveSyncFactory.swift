import Foundation
import os
import TrinketPersistence

private let entitlementLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "CloudKitEntitlement"
)

enum PlayerSaveSyncFactory {
    static func makeSyncService(
        environment: AppEnvironment = .shared,
        entitlementChecker: any CloudKitEntitlementChecking = RuntimeCloudKitEntitlementChecker(),
        cloudSyncFactory: () -> any PlayerSaveSyncing = { CloudKitPlayerSaveSync() }
    ) -> any PlayerSaveSyncing {
        let env = environment
        if env.disableCloudSync || env.resetState {
            return LocalOnlyPlayerSaveSync()
        }

        guard entitlementChecker.hasCloudKitContainer(
            identifier: CloudKitPlayerSaveSync.containerIdentifier
        ) else {
            return LocalOnlyPlayerSaveSync()
        }

        return cloudSyncFactory()
    }
}

protocol CloudKitEntitlementChecking {
    func hasCloudKitContainer(identifier: String) -> Bool
}

struct RuntimeCloudKitEntitlementChecker: CloudKitEntitlementChecking {
    private static let cloudKitServicesEntitlementKey = "com.apple.developer.icloud-services"
    private static let containerIdentifiersEntitlementKey = "com.apple.developer.icloud-container-identifiers"

    func hasCloudKitContainer(identifier: String) -> Bool {
        let entitlements = Bundle.main.signedEntitlements()
        guard
            entitlementValues(
                in: entitlements,
                for: Self.cloudKitServicesEntitlementKey
            ).contains("CloudKit"),
            entitlementValues(
                in: entitlements,
                for: Self.containerIdentifiersEntitlementKey
            ).contains(identifier)
        else {
            return false
        }

        return true
    }

    private func entitlementValues(in entitlements: [String: Any], for key: String) -> [String] {
        guard let value = entitlements[key] else { return [] }
        if let values = value as? [String] {
            return values
        }

        if let value = value as? String {
            return [value]
        }

        return []
    }
}

private extension Bundle {
    func signedEntitlements() -> [String: Any] {
        guard
            let executableURL,
            let executableData = readExecutableData(at: executableURL)
        else {
            return [:]
        }

        return executableData.embeddedPropertyListDictionaries().first { entitlements in
            entitlements["application-identifier"] != nil ||
                entitlements["com.apple.application-identifier"] != nil ||
                entitlements["com.apple.developer.icloud-container-identifiers"] != nil
        } ?? [:]
    }
}

private extension Data {
    func embeddedPropertyListDictionaries() -> [[String: Any]] {
        let startMarker = Data("<?xml".utf8)
        let endMarker = Data("</plist>".utf8)
        var dictionaries: [[String: Any]] = []
        var searchRange = startIndex ..< endIndex

        while
            let start = range(of: startMarker, options: [], in: searchRange),
            let end = range(of: endMarker, options: [], in: start.upperBound ..< endIndex) {
            let plistData = self[start.lowerBound ..< end.upperBound]
            if let dictionary = parseEmbeddedPropertyListDictionary(Data(plistData)) {
                dictionaries.append(dictionary)
            }

            searchRange = end.upperBound ..< endIndex
        }

        return dictionaries
    }
}

private func parseEmbeddedPropertyListDictionary(_ data: Data) -> [String: Any]? {
    do {
        return try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any]
    } catch {
        entitlementLogger.debug(
            "Skipped embedded plist segment: \(error.localizedDescription, privacy: .public)"
        )
        return nil
    }
}

private func readExecutableData(at url: URL) -> Data? {
    do {
        return try Data(contentsOf: url)
    } catch {
        entitlementLogger.debug(
            "Failed to read executable entitlements: \(error.localizedDescription, privacy: .public)"
        )
        return nil
    }
}
