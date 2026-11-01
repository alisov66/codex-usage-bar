import XCTest
@testable import UsageCore

final class UsageTests: XCTestCase {
    private func decode(_ json: String) throws -> UsageSnapshot {
        try JSONDecoder().decode(UsageSnapshot.self, from: Data(json.utf8))
    }

    func testMultipleBucketsTakePrecedenceOverLegacyAndUseLowestRemaining() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":99}},"rateLimitsByLimitId":{
        "other":{"primary":{"usedPercent":60,"windowDurationMins":60}},
        "codex":{"primary":{"usedPercent":25,"windowDurationMins":300},
        "secondary":{"usedPercent":30,"windowDurationMins":10080}}}}
        """)
        XCTAssertEqual(snapshot.entries.map(\.id), ["codex", "other"])
        XCTAssertEqual(snapshot.remainingPercent(), 40)
        XCTAssertEqual(snapshot.entries[0].bucket.windows.map(\.title), ["5-hour", "Weekly"])
    }

    func testLegacyFallbackAndClamping() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":-5},"secondary":{"usedPercent":125}},"rateLimitsByLimitId":{}}
        """)
        XCTAssertEqual(snapshot.windows.map(\.remainingPercent), [100, 0])
    }

    func testNullWindowsAreUnavailableRatherThanZeroUsage() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":null,"secondary":null},"rateLimitsByLimitId":null}
        """)
        XCTAssertNil(snapshot.remainingPercent())
        XCTAssertTrue(snapshot.windows.isEmpty)
    }

    func testExpiredWindowRequiresFreshData() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":80,"resetsAt":1000},"secondary":{"usedPercent":20,"resetsAt":3000}}}
        """)
        XCTAssertEqual(snapshot.remainingPercent(at: Date(timeIntervalSince1970: 999)), 20)
        XCTAssertNil(snapshot.remainingPercent(at: Date(timeIntervalSince1970: 1000)))
    }

    func testFractionalQuotaDoesNotOverstateRemaining() throws {
        let snapshot = try decode("""
        {"rateLimits":{"primary":{"usedPercent":25.4,"windowDurationMins":15}}}
        """)
        XCTAssertEqual(snapshot.remainingPercent(), 74)
        XCTAssertEqual(snapshot.windows.first?.title, "15-minute")
    }

    func testExecutableMustBeAFileAndCustomPathDoesNotSilentlyFallback() {
        XCTAssertNil(CodexExecutable.locate(customPath: "/usr/bin"))
        XCTAssertNil(CodexExecutable.locate(customPath: "/this-path-does-not-exist/codex"))
        XCTAssertEqual(CodexExecutable.locate(customPath: "/bin/sh"), "/bin/sh")
    }
}
