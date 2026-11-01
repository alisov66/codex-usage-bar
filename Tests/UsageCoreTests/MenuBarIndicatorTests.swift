import XCTest
@testable import UsageCore

final class MenuBarIndicatorTests: XCTestCase {
    func testAllDesignVariantsUseRemainingQuota() {
        let snapshot = UsageSnapshot.menuBarPreview
        let both = MenuBarIndicator(snapshot: snapshot, display: .both, isStale: false)
        XCTAssertEqual(both.quotas.map(\.label), ["5h", "7d"])
        XCTAssertEqual(both.quotas.map(\.value), ["68%", "92%"])
        XCTAssertEqual(MenuBarIndicator(snapshot: snapshot, display: .fiveHour, isStale: false).quotas.map(\.value), ["68%"])
        XCTAssertEqual(MenuBarIndicator(snapshot: snapshot, display: .weekly, isStale: false).quotas.map(\.value), ["92%"])
        XCTAssertTrue(both.accessibilityLabel.contains("68 percent remaining"))
    }

    func testMissingAndStaleReadingsDoNotAppearAsUnusedQuota() {
        for snapshot in [nil, UsageSnapshot.menuBarPreview] {
            let indicator = MenuBarIndicator(snapshot: snapshot, display: .both, isStale: true)
            XCTAssertEqual(indicator.quotas.map(\.value), ["—", "—"])
            XCTAssertTrue(indicator.accessibilityLabel.contains("unavailable"))
        }
    }

    func testExpirationOnlyInvalidatesTheExpiredWindow() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":32,"windowDurationMins":300,"resetsAt":1000},
        "secondary":{"usedPercent":8,"windowDurationMins":10080,"resetsAt":3000}}}
        """)
        let indicator = MenuBarIndicator(snapshot: snapshot, display: .both, isStale: false, now: Date(timeIntervalSince1970: 2000))
        XCTAssertEqual(indicator.quotas.map(\.value), ["—", "92%"])
    }

    func testUnexpectedWindowIsNotMislabeledFiveHour() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":32,"windowDurationMins":15},
        "secondary":{"usedPercent":8,"windowDurationMins":10080}}}
        """)
        let indicator = MenuBarIndicator(snapshot: snapshot, display: .both, isStale: false)
        XCTAssertEqual(indicator.quotas.map(\.value), ["—", "92%"])
    }

    func testBucketsAreNotMixedAndCodexTakesPrecedence() throws {
        let snapshot = try decode("""
        {"rateLimitsByLimitId":{
        "another":{"primary":{"usedPercent":1,"windowDurationMins":300},"secondary":{"usedPercent":2,"windowDurationMins":10080}},
        "codex":{"primary":{"usedPercent":32,"windowDurationMins":300}}}}
        """)
        let indicator = MenuBarIndicator(snapshot: snapshot, display: .both, isStale: false)
        XCTAssertEqual(indicator.quotas.map(\.value), ["68%", "—"])
    }

    func testHundredAndZeroPercentRemainDistinct() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":0,"windowDurationMins":300},
        "secondary":{"usedPercent":100,"windowDurationMins":10080}}}
        """)
        XCTAssertEqual(MenuBarIndicator(snapshot: snapshot, display: .both, isStale: false).quotas.map(\.value), ["100%", "0%"])
    }

    private func decode(_ json: String) throws -> UsageSnapshot {
        try JSONDecoder().decode(UsageSnapshot.self, from: Data(json.utf8))
    }
}
