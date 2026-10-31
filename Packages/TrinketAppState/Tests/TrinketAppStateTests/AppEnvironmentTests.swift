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

    @Test func `unlocked development launch isolates its save and cannot enable cloud sync`() {
        let environment = Self.parse(
            arguments: ["-development-unlocked", "-store-name", "ordinary-save", "-enable-cloud-sync"],
            cloudDefault: true,
        )
        #if DEBUG
        #expect(environment.developmentUnlocked)
        #expect(environment.storeName == "development-unlocked")
        #expect(environment.disableCloudSync)
        #else
        #expect(!environment.developmentUnlocked)
        #expect(environment.storeName == "ordinary-save")
        #endif
        #expect(!Self.parse(arguments: []).developmentUnlocked)
    }

    @Test func `terminal Shop failure fixture requires an isolated development save`() {
        let flag = "-terminal-shop-save-failure"
        #expect(!Self.parse(arguments: [flag]).terminalShopFailureFixture)
        let environment = Self.parse(arguments: ["-development-unlocked", flag, "-enable-cloud-sync"])
        #if DEBUG
        #expect(environment.terminalShopFailureFixture)
        #expect(environment.disableCloudSync)
        #else
        #expect(!environment.terminalShopFailureFixture)
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
