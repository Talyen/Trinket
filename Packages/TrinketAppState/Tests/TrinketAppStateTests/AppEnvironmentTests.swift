import Testing
@testable import TrinketAppState

struct AppEnvironmentTests {
    @Test(arguments: ["-disable-cloud-sync", "-reset-state", "-seed-test-progress"], [false, true])
    func `local safety flags override cloud opt in and build default`(flag: String, cloudDefault: Bool) {
        #expect(Self.parse(arguments: ["-enable-cloud-sync", flag], cloudDefault: cloudDefault).disableCloudSync)
    }

    @Test(arguments: [false, true])
    func `runners override cloud opt in and build default`(cloudDefault: Bool) {
        #expect(Self.parse(
            arguments: ["-enable-cloud-sync"],
            environment: ["XCTestConfigurationFilePath": "isolated-tests"],
            cloudDefault: cloudDefault,
        ).disableCloudSync)
    }

    @Test(arguments: [false, true])
    func `cloud build default controls ordinary launch`(cloudDefault: Bool) {
        let environment = Self.parse(arguments: [], cloudDefault: cloudDefault)
        #expect(environment.disableCloudSync == !cloudDefault)
        #expect(!environment.resetState)
        #expect(!environment.seedTestProgress)
    }

    @Test func `cloud launch opt in respects build configuration`() {
        #if DEBUG
        #expect(!Self.parse(arguments: ["-enable-cloud-sync"]).disableCloudSync)
        #else
        #expect(Self.parse(arguments: ["-enable-cloud-sync"]).disableCloudSync)
        #endif
    }

    private static let emptyEnvironment: [String: String] = [:]

    private static func parse(
        arguments: [String],
        environment: [String: String]? = nil,
        cloudDefault: Bool = false,
    ) -> AppEnvironment {
        AppEnvironment.parse(
            arguments: arguments,
            environment: environment ?? emptyEnvironment,
            cloudSyncEnabledByDefault: cloudDefault,
        )
    }
}
