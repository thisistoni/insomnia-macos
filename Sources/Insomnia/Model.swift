import AppKit
import InsomniaCore
import ServiceManagement
import SwiftUI

@MainActor final class AppModel: ObservableObject {
  @Published var preferences: Preferences { didSet { save() } }
  @Published var accessibilityTrusted = AXIsProcessTrusted()
  @Published var armed = false
  @Published var sensors = readSensors()
  @Published var lidClosed = false
  @Published var message = "Ready when you are"
  @Published var deadline: Date?
  @Published var started: Date?
  @Published var sessions: [AgentSession] = []
  @Published var connected: Set<String> = []
  @Published var tab = "Wake"
  @Published var login = SMAppService.mainApp.status == .enabled
  @Published var error: String?
  @Published var history: [String] = []
  @Published var showWelcome = !UserDefaults.standard.bool(forKey: "welcomed")
  var registry = SessionRegistry()
  var armingSound: NSSound?
  var monitoringActivity: NSObjectProtocol?
  var helper: Process?
  var heartbeat: FileHandle?
  var poll: Timer?
  var globalMonitor: Any?
  var localMonitor: Any?
  var automatic = false
  var paused = false
  var previousActive = false
  var fnDown = false
  var showOverlay: (() -> Void)?
  var hideOverlay: (() -> Void)?
  init() {
    if let data = UserDefaults.standard.data(forKey: "preferences"),
      let p = try? JSONDecoder().decode(Preferences.self, from: data)
    {
      preferences = p
    } else {
      preferences = Preferences()
    }
    try? Paths.prepare()
    PowerControl.recoverIfNeeded()
    refreshConnections()
    poll = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in self?.tick() }
    }
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
      Task { @MainActor [weak self] in self?.handleFlags(e) }
    }
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
      self?.handleFlags(e)
      return e
    }
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
    ) { [weak self] _ in Task { @MainActor [weak self] in self?.handleSleepRequest() } }
  }
  func save() {
    if let data = try? JSONEncoder().encode(preferences) {
      UserDefaults.standard.set(data, forKey: "preferences")
    }
  }
  func log(_ s: String) {
    history.insert("\(Date().formatted(date: .omitted, time: .standard))  \(s)", at: 0)
    history = Array(history.prefix(100))
  }
  func refreshConnections() {
    connected = Set(Integration.all.filter { $0.installed() }.map(\.name))
  }
  func connect(_ integration: Integration) {
    do {
      try integration.setInstalled(!connected.contains(integration.name))
      refreshConnections()
      log("\(integration.name) connection updated")
    } catch { self.error = error.localizedDescription }
  }
  func setLogin(_ value: Bool) {
    do {
      if value {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      login = SMAppService.mainApp.status == .enabled
    } catch {
      self.error = error.localizedDescription
      login = SMAppService.mainApp.status == .enabled
    }
  }
  func arm(minutes: Double? = nil, automatically: Bool = false) {
    guard !armed else { return }
    guard helper?.isRunning != true else {
      message = "Restoring normal sleep; try again shortly"
      return
    }
    sensors = readSensors()
    if let reason = Safety.stopReason(sensors, preferences) {
      message = reason
      if automatically { paused = true } else { error = reason }
      return
    }
    let process = Process()
    let input = Pipe()
    let output = Pipe()
    process.executableURL = Bundle.main.executableURL
    process.arguments = ["--power-helper"] + (preferences.keepOpen ? [] : ["--allow-idle"])
    process.standardInput = input
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      // Helper emits a bounded single-line startup result before reading its heartbeat pipe.
      let data = output.fileHandleForReading.availableData
      let response = String(data: data, encoding: .utf8) ?? ""
      guard response.hasPrefix("READY") else {
        try? input.fileHandleForWriting.close()
        error =
          response.isEmpty
          ? "Power controller did not start"
          : response.trimmingCharacters(in: .whitespacesAndNewlines)
        message = "Could not arm"
        return
      }
      helper = process
      heartbeat = input.fileHandleForWriting
      monitoringActivity = ProcessInfo.processInfo.beginActivity(
        options: .userInitiatedAllowingIdleSystemSleep,
        reason: "Monitor Insomnia safety and watchdog")
      armed = true
      automatic = automatically
      paused = false
      started = Date()
      deadline = minutes.map { Date().addingTimeInterval($0 * 60) }
      message = automatically ? "Keeping your agents working" : "You can close the lid"
      let agents = Array(
        Set(
          sessions.filter {
            $0.state == "working" || preferences.keepWaiting && $0.state == "waiting"
          }.map(\.agent))
      ).sorted().joined(separator: ", ")
      log(automatically ? "Keep awake started by \(agents)" : "Keep awake started manually")
      if preferences.sound { playChime() }
    } catch {
      self.error = error.localizedDescription
      message = "Could not arm"
    }
  }
  func disarm(_ reason: String = "Normal sleep restored", pauseAutomation: Bool = true) {
    if armed { log(reason) }
    try? heartbeat?.write(contentsOf: Data("STOP\n".utf8))
    try? heartbeat?.close()
    heartbeat = nil
    if let monitoringActivity {
      ProcessInfo.processInfo.endActivity(monitoringActivity)
      self.monitoringActivity = nil
    }
    armed = false
    automatic = false
    deadline = nil
    started = nil
    message = reason
    if pauseAutomation { paused = true }
    hideOverlay?()
  }
  func handleSleepRequest() {
    // A pending clamshell sleep notification must not tear down the very override
    // that is keeping this session alive. Explicit sleep with the lid open still ends it.
    if armed && registryValueLid() {
      log("Closed-lid sleep request received; retaining session")
    } else {
      disarm("Mac went to sleep")
    }
  }

  func handleFlags(_ event: NSEvent) {
    let down = event.modifierFlags.contains(.function)
    guard down != fnDown else { return }
    fnDown = down
    if down && preferences.fnArming && !armed {
      arm()
      if armed { showOverlay?() }
    }
    if !down { hideOverlay?() }
  }
  func tick() {
    let trusted = AXIsProcessTrusted()
    if accessibilityTrusted != trusted { accessibilityTrusted = trusted }
    let currentSensors = readSensors()
    if sensors != currentSensors { sensors = currentSensors }
    let closed = registryValueLid()
    if closed != lidClosed {
      lidClosed = closed
      if closed && armed {
        if preferences.lockOnLidClose { lockScreen() }
        hideOverlay?()
        log("Lid closed")
      }
      if !closed && armed && !preferences.stayArmed { disarm("Lid opened") }
    }
    if let files = try? FileManager.default.contentsOfDirectory(
      at: Paths.events, includingPropertiesForKeys: nil)
    {
      let events = files.compactMap { url -> (URL, AgentEvent)? in
        guard let data = try? Data(contentsOf: url),
          let event = try? JSONDecoder().decode(AgentEvent.self, from: data)
        else {
          try? FileManager.default.removeItem(at: url)
          return nil
        }
        return (url, event)
      }.sorted { $0.1.timestamp < $1.1.timestamp }
      for (url, event) in events {
        let before = registry.sessions
        registry.apply(event)
        let key = event.agent + ":" + event.session
        if before[key]?.state != registry.sessions[key]?.state {
          let state =
            event.state == "finished"
            ? "finished" : event.state == "waiting" ? "waiting for approval" : "working"
          log("\(event.agent): \(state)")
        }
        try? FileManager.default.removeItem(at: url)
      }
    }
    let previousAgents = Array(Set(sessions.map(\.agent))).sorted().joined(separator: ", ")
    registry.expire(now: Date(), hours: preferences.maximumHours)
    let currentSessions = registry.sessions.values.sorted { $0.started < $1.started }
    if sessions != currentSessions { sessions = currentSessions }
    let active = registry.active(keepWaiting: preferences.keepWaiting)
    if !active { paused = false }
    if armed {
      if helper?.isRunning != true {
        PowerControl.recoverIfNeeded()
        disarm("Power controller stopped")
        paused = true
        return
      }
      do { try heartbeat?.write(contentsOf: Data("BEAT\n".utf8)) } catch {
        disarm("Power controller disconnected")
        return
      }
      if let reason = Safety.stopReason(sensors, preferences) {
        disarm(reason)
        return
      }
      if let deadline, Date() >= deadline {
        disarm("Timer finished")
        return
      }
      if let started, Date().timeIntervalSince(started) >= preferences.maximumHours * 3600 {
        disarm("Maximum session duration reached")
        return
      }
      if AutomationPolicy.shouldStop(
        automatic: automatic, enabled: preferences.autoStop, wasActive: previousActive,
        isActive: active)
      {
        disarm("Sleep allowed — \(previousAgents) no longer active", pauseAutomation: false)
      }
    } else if preferences.autoArm && active && !paused {
      arm(automatically: true)
    }
    previousActive = active
    if armed && lidClosed && message != "Working with the lid closed" {
      message = "Working with the lid closed"
    }
  }
  func registryValueLid() -> Bool {
    registryProperties("IOPMrootDomain")["AppleClamshellState"] as? Bool ?? false
  }

  func diagnostics() -> String {
    "Insomnia 1.0\nmacOS \(ProcessInfo.processInfo.operatingSystemVersionString)\nArmed: \(armed)\nLid closed: \(lidClosed)\nBattery: \(sensors.battery.map { String(format: "%.0f%%", $0) } ?? "unavailable")\nTemperature: \(sensors.temperature.map { String(format: "%.1f°C", $0) } ?? "unavailable")\nThermal pressure: \(sensors.thermal)\nAgent sessions: \(sessions.count)\nConnections: \(connected.sorted().joined(separator: ", "))\n\n"
      + history.joined(separator: "\n")
  }
  func playChime() {
    if armingSound == nil,
      let url = Bundle.main.url(forResource: "Insomnia-Chime", withExtension: "wav")
    {
      armingSound = NSSound(contentsOf: url, byReference: false)
    }
    armingSound?.stop()
    armingSound?.play()
  }

  func lockScreen() {
    guard accessibilityTrusted,
      let down = CGEvent(keyboardEventSource: nil, virtualKey: 12, keyDown: true),
      let up = CGEvent(keyboardEventSource: nil, virtualKey: 12, keyDown: false)
    else {
      log("Screen lock needs Accessibility")
      return
    }
    down.flags = [.maskControl, .maskCommand]
    up.flags = [.maskControl, .maskCommand]
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }
  func requestAccessibility() {
    let options =
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    NSWorkspace.shared.open(
      URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
  }
  func copyDiagnostics() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(diagnostics(), forType: .string)
  }
  func finishWelcome() {
    showWelcome = false
    UserDefaults.standard.set(true, forKey: "welcomed")
  }
}
