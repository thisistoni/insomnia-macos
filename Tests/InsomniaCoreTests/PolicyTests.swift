import XCTest

@testable import InsomniaCore

final class PolicyTests: XCTestCase {
  func testAgentCompletionNeverEndsManualSession() {
    XCTAssertFalse(
      AutomationPolicy.shouldStop(automatic: false, enabled: true, wasActive: true, isActive: false)
    )
    XCTAssertTrue(
      AutomationPolicy.shouldStop(automatic: true, enabled: true, wasActive: true, isActive: false))
    XCTAssertFalse(
      AutomationPolicy.shouldStop(automatic: true, enabled: true, wasActive: true, isActive: true))
    XCTAssertFalse(
      AutomationPolicy.shouldStop(automatic: true, enabled: false, wasActive: true, isActive: false)
    )
  }
  func testBatteryGuardIgnoresChargingButStopsAtThreshold() {
    let p = Preferences()
    XCTAssertNil(
      Safety.stopReason(Sensors(battery: 10, charging: true, temperature: 30, thermal: 0), p))
    XCTAssertEqual(
      Safety.stopReason(Sensors(battery: 20, charging: false, temperature: 30, thermal: 0), p),
      "Low battery limit reached")
  }
  func testSafetyFailsClosedForMissingSensorAndThermalPressure() {
    let p = Preferences()
    XCTAssertNotNil(
      Safety.stopReason(Sensors(battery: 80, charging: false, temperature: nil, thermal: 0), p))
    XCTAssertNotNil(
      Safety.stopReason(Sensors(battery: 80, charging: true, temperature: 30, thermal: 2), p))
  }
  func testMultipleAgentsAndApprovalPolicy() {
    var r = SessionRegistry()
    let now = Date()
    r.apply(AgentEvent(agent: "Codex", session: "a", state: "working", timestamp: now), now: now)
    r.apply(
      AgentEvent(agent: "Claude Code", session: "b", state: "working", timestamp: now), now: now)
    r.apply(AgentEvent(agent: "Codex", session: "a", state: "finished", timestamp: now), now: now)
    XCTAssertTrue(r.active(keepWaiting: false))
    r.apply(
      AgentEvent(agent: "Claude Code", session: "b", state: "waiting", timestamp: now), now: now)
    XCTAssertFalse(r.active(keepWaiting: false))
    XCTAssertTrue(r.active(keepWaiting: true))
    r.expire(now: now.addingTimeInterval(3601), hours: 1)
    XCTAssertFalse(r.active(keepWaiting: true))
  }
  func testLateStartCannotResurrectFinishedSession() {
    var r = SessionRegistry()
    let now = Date()
    r.apply(AgentEvent(agent: "Codex", session: "a", state: "finished", timestamp: now), now: now)
    r.apply(
      AgentEvent(
        agent: "Codex", session: "a", state: "working", timestamp: now.addingTimeInterval(-1)),
      now: now)
    XCTAssertTrue(r.sessions.isEmpty)
  }
  func testMalformedHookConfigIsRejected() {
    XCTAssertThrowsError(
      try HookConfig.update(Data("[]".utf8), agent: "Codex", executable: "/app", installing: true))
    XCTAssertThrowsError(
      try HookConfig.update(
        Data(#"{"hooks":{"Stop":"other"}}"#.utf8), agent: "Codex", executable: "/app",
        installing: true))
  }
  func testStaleEventsCannotStartSessions() {
    var r = SessionRegistry()
    r.apply(
      AgentEvent(
        agent: "Codex", session: "old", state: "working", timestamp: Date().addingTimeInterval(-120)
      ))
    XCTAssertTrue(r.sessions.isEmpty)
  }
  func testHookInstallIsIdempotentAndUninstallPreservesOtherHandlers() throws {
    let original = Data(
      #"{"theme":"dark","hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"my-hook"}]}]}}"#
        .utf8)
    let once = try HookConfig.update(
      original, agent: "Codex", executable: "/test/app's executable", installing: true)
    let twice = try HookConfig.update(
      once, agent: "Codex", executable: "/test/app's executable", installing: true)
    XCTAssertEqual(once, twice)
    let removed = try HookConfig.update(
      twice, agent: "Codex", executable: "/test/app's executable", installing: false)
    let json = try JSONSerialization.jsonObject(with: removed) as! [String: Any]
    XCTAssertEqual(json["theme"] as? String, "dark")
    let text = String(data: removed, encoding: .utf8)!
    XCTAssertTrue(text.contains("my-hook"))
    XCTAssertFalse(text.contains("--stillon-hook"))
  }
}
