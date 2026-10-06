import Foundation

public struct Preferences: Codable, Equatable {
  public var batteryGuard = true
  public var batteryLimit = 20.0
  public var thermalGuard = true
  public var temperatureGuard = true
  public var temperatureLimit = 45.0
  public var keepOpen = true
  public var lockOnLidClose = false
  public var stayArmed = false
  public var fnArming = true
  public var sound = true
  public var autoArm = true
  public var autoStop = true
  public var keepWaiting = false
  public var maximumHours = 12.0
  public init() {}
  enum CodingKeys: String, CodingKey {
    case batteryGuard, batteryLimit, thermalGuard, temperatureGuard, temperatureLimit, keepOpen,
      lockOnLidClose, stayArmed, fnArming, sound, autoArm, autoStop, keepWaiting, maximumHours
  }
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    batteryGuard = try values.decodeIfPresent(Bool.self, forKey: .batteryGuard) ?? batteryGuard
    batteryLimit = try values.decodeIfPresent(Double.self, forKey: .batteryLimit) ?? batteryLimit
    thermalGuard = try values.decodeIfPresent(Bool.self, forKey: .thermalGuard) ?? thermalGuard
    temperatureGuard =
      try values.decodeIfPresent(Bool.self, forKey: .temperatureGuard) ?? temperatureGuard
    temperatureLimit =
      try values.decodeIfPresent(Double.self, forKey: .temperatureLimit) ?? temperatureLimit
    keepOpen = try values.decodeIfPresent(Bool.self, forKey: .keepOpen) ?? keepOpen
    lockOnLidClose =
      try values.decodeIfPresent(Bool.self, forKey: .lockOnLidClose) ?? lockOnLidClose
    stayArmed = try values.decodeIfPresent(Bool.self, forKey: .stayArmed) ?? stayArmed
    fnArming = try values.decodeIfPresent(Bool.self, forKey: .fnArming) ?? fnArming
    sound = try values.decodeIfPresent(Bool.self, forKey: .sound) ?? sound
    autoArm = try values.decodeIfPresent(Bool.self, forKey: .autoArm) ?? autoArm
    autoStop = try values.decodeIfPresent(Bool.self, forKey: .autoStop) ?? autoStop
    keepWaiting = try values.decodeIfPresent(Bool.self, forKey: .keepWaiting) ?? keepWaiting
    maximumHours = try values.decodeIfPresent(Double.self, forKey: .maximumHours) ?? maximumHours
  }
}
public struct Sensors: Equatable {
  public var battery: Double?
  public var charging: Bool
  public var temperature: Double?
  public var thermal: Int
  public init(battery: Double?, charging: Bool, temperature: Double?, thermal: Int) {
    self.battery = battery
    self.charging = charging
    self.temperature = temperature
    self.thermal = thermal
  }
}
public enum Safety {
  public static func stopReason(_ s: Sensors, _ p: Preferences) -> String? {
    if p.batteryGuard && !s.charging {
      guard let battery = s.battery else { return "Battery reading unavailable" }
      if battery <= p.batteryLimit { return "Low battery limit reached" }
    }
    if p.thermalGuard && s.thermal >= 2 { return "Mac thermal pressure is too high" }
    if p.temperatureGuard {
      guard let t = s.temperature else { return "Battery temperature unavailable" }
      if t >= p.temperatureLimit { return "Battery temperature limit reached" }
    }
    return nil
  }
}
public struct AgentEvent: Codable {
  public var agent: String
  public var session: String
  public var state: String
  public var timestamp: Date
  public init(agent: String, session: String, state: String, timestamp: Date = Date()) {
    self.agent = agent
    self.session = session
    self.state = state
    self.timestamp = timestamp
  }
}
public struct AgentSession: Identifiable, Equatable {
  public var id: String
  public var agent: String
  public var state: String
  public var started: Date
  public var updated: Date
}
public struct SessionRegistry {
  public private(set) var sessions: [String: AgentSession] = [:]
  private var lastUpdates: [String: Date] = [:]
  public init() {}
  public mutating func apply(_ event: AgentEvent, now: Date = Date()) {
    guard ["working", "waiting", "finished"].contains(event.state), !event.session.isEmpty,
      abs(event.timestamp.timeIntervalSince(now)) < 60
    else { return }
    let key = event.agent + ":" + event.session
    if let last = lastUpdates[key], event.timestamp < last { return }
    lastUpdates[key] = event.timestamp
    if event.state == "finished" {
      sessions.removeValue(forKey: key)
      return
    }
    sessions[key] = AgentSession(
      id: key, agent: event.agent, state: event.state,
      started: sessions[key]?.started ?? event.timestamp, updated: event.timestamp)
  }
  public mutating func expire(now: Date, hours: Double) {
    lastUpdates = lastUpdates.filter { now.timeIntervalSince($0.value) < hours * 3600 }
    sessions = sessions.filter { now.timeIntervalSince($0.value.updated) < hours * 3600 }
  }
  public func active(keepWaiting: Bool) -> Bool {
    sessions.values.contains { $0.state == "working" || keepWaiting && $0.state == "waiting" }
  }
}
public enum HookConfig {
  public enum ConfigError: Error { case invalidFormat }
  public static func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
  public static func update(_ data: Data?, agent: String, executable: String, installing: Bool)
    throws -> Data
  {
    var root: [String: Any] = [:]
    if let data {
      guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw ConfigError.invalidFormat
      }
      root = parsed
    }
    if let existing = root["hooks"], !(existing is [String: Any]) {
      throw ConfigError.invalidFormat
    }
    var hooks = root["hooks"] as? [String: Any] ?? [:]
    let flat = agent == "Cursor"
    let events =
      flat
      ? [
        "beforeSubmitPrompt": "working", "preToolUse": "working", "postToolUse": "working",
        "stop": "finished", "sessionEnd": "finished",
      ]
      : [
        "UserPromptSubmit": "working", "PreToolUse": "working", "PostToolUse": "working",
        "PermissionRequest": "waiting", "Stop": "finished", "SessionEnd": "finished",
      ]
    for (event, state) in events {
      if let existing = hooks[event], !(existing is [[String: Any]]) {
        throw ConfigError.invalidFormat
      }
      var list = hooks[event] as? [[String: Any]] ?? []
      // Remove only this app's handlers, retaining other handlers even in a shared matcher group.
      list = list.compactMap { item in
        var item = item
        if flat {
          return (item["command"] as? String)?.contains("--stillon-hook") == true ? nil : item
        }
        if let children = item["hooks"] as? [[String: Any]] {
          let kept = children.filter {
            ($0["command"] as? String)?.contains("--stillon-hook") != true
          }
          if kept.isEmpty { return nil }
          item["hooks"] = kept
        }
        return item
      }
      if installing {
        let command = shellQuote(executable) + " --stillon-hook " + shellQuote(agent) + " " + state
        if flat {
          list.append(["command": command])
        } else {
          list.append([
            "matcher": "", "hooks": [["type": "command", "command": command, "timeout": 3]],
          ])
        }
      }
      hooks[event] = list
    }
    root["hooks"] = hooks
    if flat { root["version"] = 1 }
    return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
  }
}

/// Agent completion only owns sessions started by automation.
public enum AutomationPolicy {
  public static func shouldStop(automatic: Bool, enabled: Bool, wasActive: Bool, isActive: Bool)
    -> Bool
  {
    automatic && enabled && wasActive && !isActive
  }
}
