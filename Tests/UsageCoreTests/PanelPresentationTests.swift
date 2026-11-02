import XCTest
@testable import UsageCore

final class PanelPresentationTests: XCTestCase {
    private func decode(_ json: String) throws -> UsageSnapshot {
        try JSONDecoder().decode(UsageSnapshot.self, from: Data(json.utf8))
    }

    func testInitialLoadAndAutomaticRefreshDoNotLookLikeFailedRetries() {
        XCTAssertEqual(PanelPhase(hasData: false, isRefreshing: true, isStale: true, failure: nil), .loading)
        XCTAssertEqual(PanelPhase(hasData: true, isRefreshing: true, isStale: false, failure: nil), .ready)
        XCTAssertEqual(PanelPhase(hasData: true, isRefreshing: false, isStale: false, failure: nil), .ready)
    }

    func testFailureAndRetryWorkWithAndWithoutPreviousData() {
        for hasData in [true, false] {
            XCTAssertEqual(PanelPhase(hasData: hasData, isRefreshing: false, isStale: true, failure: .refresh), .refreshFailed)
            XCTAssertEqual(PanelPhase(hasData: hasData, isRefreshing: true, isStale: true, failure: .refresh), .retrying)
        }
        XCTAssertEqual(PanelPhase(hasData: true, isRefreshing: false, isStale: true, failure: nil), .refreshFailed)
    }

    func testSetupFailuresHaveSpecificRecoveryStates() {
        XCTAssertEqual(PanelPhase(hasData: true, isRefreshing: false, isStale: true, failure: .codexMissing), .codexMissing)
        XCTAssertEqual(PanelPhase(hasData: false, isRefreshing: false, isStale: true, failure: .signInRequired), .signInRequired)
        XCTAssertEqual(PanelFailure(error: CodexError.missingExecutable), .codexMissing)
        XCTAssertEqual(PanelFailure(error: CodexError.service("Sign in with ChatGPT")), .signInRequired)
        XCTAssertEqual(PanelFailure(error: CodexError.service("Not signed in")), .signInRequired)
        XCTAssertEqual(PanelFailure(error: CodexError.timeout), .refresh)
        XCTAssertEqual(PanelFailure(error: CodexError.service("Rate limit endpoint unavailable")), .refresh)
    }

    func testPanelUsesCodexBucketAndKeepsUnavailableWindowDistinctFromZero() throws {
        let snapshot = try decode("""
        {"rateLimitsByLimitId":{
          "other":{"primary":{"usedPercent":0,"windowDurationMins":300}},
          "codex":{"primary":null,"secondary":{"usedPercent":100,"windowDurationMins":10080}}}}
        """)
        XCTAssertEqual(snapshot.panelQuotas.map(\.title), ["5-hour limit", "Weekly limit"])
        XCTAssertNil(snapshot.panelQuotas[0].remainingPercent(at: Date()))
        XCTAssertEqual(snapshot.panelQuotas[1].remainingPercent(at: Date()), 0)
        XCTAssertEqual(snapshot.panelQuotas[0].resetText(at: Date()), "—")
    }

    func testExpiredQuotaNeverLooksLikeNewlyResetQuota() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":60,"windowDurationMins":300,"resetsAt":1000}}}
        """)
        let quota = snapshot.panelQuotas[0]
        XCTAssertEqual(quota.remainingPercent(at: Date(timeIntervalSince1970: 999)), 40)
        XCTAssertNil(quota.remainingPercent(at: Date(timeIntervalSince1970: 1000)))
        XCTAssertEqual(quota.resetText(at: Date(timeIntervalSince1970: 1001)), "Awaiting refresh")
    }

    func testResetCountdownUsesReadableUnitsWithoutNegativeOrZeroMinutePlaceholder() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":50,"windowDurationMins":300,"resetsAt":8470},
        "secondary":{"usedPercent":50,"windowDurationMins":10080,"resetsAt":576010}}}
        """)
        let now = Date(timeIntervalSince1970: 10)
        XCTAssertEqual(snapshot.panelQuotas[0].resetText(at: now), "2 h 21 min")
        XCTAssertEqual(snapshot.panelQuotas[1].resetText(at: now), "6 days 16 h")
        XCTAssertEqual(snapshot.panelQuotas[0].resetText(at: Date(timeIntervalSince1970: 8469)), "1 min")
    }

    func testNonstandardAccountWindowKeepsItsActualDuration() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":20,"windowDurationMins":60}}}
        """)
        XCTAssertEqual(snapshot.panelQuotas.count, 1)
        XCTAssertEqual(snapshot.panelQuotas[0].title, "1-hour limit")
        XCTAssertEqual(snapshot.panelQuotas[0].remainingPercent(at: Date()), 80)
    }
}
