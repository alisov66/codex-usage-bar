import XCTest
@testable import UsageCore

final class CodexClientTests: XCTestCase {
    private func executable(body: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try ("#!/usr/bin/python3\nimport sys, json\n" + body).write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testHandshakeFragmentedRepliesAndRepeatedReads() async throws {
        let fake = try executable(body: """
        for line in sys.stdin:
            request = json.loads(line)
            if 'id' not in request: continue
            if request['method'] == 'initialize':
                result = {'userAgent': 'test'}
            elif request['method'] == 'account/rateLimits/read':
                result = {'rateLimits': {'primary': {'usedPercent': 28, 'windowDurationMins': 300}}}
            else:
                sys.exit(1)
            response = json.dumps({'id': request['id'], 'result': result}) + '\\n'
            sys.stdout.write(response[:8]); sys.stdout.flush()
            sys.stdout.write(response[8:]); sys.stdout.flush()
        """)
        let client = CodexClient()
        let first = try await client.readLimits(executablePath: fake.path)
        let second = try await client.readLimits(executablePath: fake.path)
        XCTAssertEqual(first.remainingPercent(), 72)
        XCTAssertEqual(second.remainingPercent(), 72)
        await client.shutdown()
    }

    func testServiceErrorReachesCaller() async throws {
        let fake = try executable(body: """
        for line in sys.stdin:
            r = json.loads(line)
            if 'id' not in r: continue
            response = {'id': r['id'], 'result': {}} if r['method'] == 'initialize' else {'id': r['id'], 'error': {'code': -1, 'message': 'Sign in with ChatGPT'}}
            print(json.dumps(response), flush=True)
        """)
        let client = CodexClient()
        do {
            _ = try await client.readLimits(executablePath: fake.path)
            XCTFail("Expected a service error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Sign in with ChatGPT")
        }
        await client.shutdown()
    }

    func testUnexpectedExitFailsPendingRequest() async throws {
        let fake = try executable(body: "sys.exit(0)\n")
        let client = CodexClient()
        do {
            _ = try await client.readLimits(executablePath: fake.path)
            XCTFail("Expected a disconnected error")
        } catch {
            XCTAssertTrue(error is CodexError)
        }
        await client.shutdown()
    }
}
