import AppKit
import InsomniaCore
import SwiftUI

let accent = Color(red: 0.40, green: 0.75, blue: 1)
let night = Color(red: 0.055, green: 0.08, blue: 0.14)
struct InsomniaMark: View {
  var active = false
  var body: some View {
    Group {
      if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
        let icon = NSImage(contentsOf: url)
      {
        Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
      } else {
        Image(systemName: "eye").resizable().scaledToFit().foregroundStyle(accent)
      }
    }.frame(width: 82, height: 82).opacity(active ? 1 : 0.92)

  }
}
private struct SessionGroup: Identifiable {
  let agent: String
  let count: Int
  let working: Bool
  var id: String { agent }
}

struct PanelView: View {
  @ObservedObject var model: AppModel
  var openSettings: () -> Void
  @State var duration = 0.0
  private var sessionGroups: [SessionGroup] {
    Dictionary(grouping: model.sessions, by: \.agent).map { agent, sessions in
      SessionGroup(
        agent: agent, count: sessions.count, working: sessions.contains { $0.state == "working" })
    }.sorted { $0.agent < $1.agent }
  }
  var body: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Insomnia").font(.system(size: 14, weight: .semibold))
        Spacer()
        Circle().fill(model.armed ? accent : .secondary).frame(width: 6, height: 6)
      }
      VStack(spacing: 13) {
        InsomniaMark(active: model.armed)
        Text(model.armed ? "Still working." : "Let it work.").font(
          .system(size: 28, weight: .semibold, design: .rounded))
        Text(model.message).font(.system(size: 12)).foregroundStyle(.secondary)
      }.padding(.vertical, 5)
      HStack {
        Label(
          model.sensors.battery.map { "\(Int($0))%" } ?? "—",
          systemImage: model.sensors.charging ? "battery.100.bolt" : "battery.75")
        Spacer()
        Label(
          model.sensors.temperature.map { String(format: "%.1f°C", $0) } ?? "Unavailable",
          systemImage: "thermometer.medium")
        Spacer()
        Image(systemName: model.lidClosed ? "laptopcomputer.slash" : "laptopcomputer")
      }.font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).padding(12).background(
        .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
      if !model.armed {
        Picker("Keep awake", selection: $duration) {
          Text("Until I allow sleep").tag(0.0)
          Text("15 minutes").tag(15.0)
          Text("30 minutes").tag(30.0)
          Text("1 hour").tag(60.0)
          Text("2 hours").tag(120.0)
          Text("4 hours").tag(240.0)
        }.labelsHidden().frame(maxWidth: .infinity)
      } else if let deadline = model.deadline {
        HStack {
          Text("Time remaining")
          Spacer()
          Text(deadline, style: .timer).monospacedDigit()
        }.font(.system(size: 12)).foregroundStyle(.secondary)
      }
      Button {
        if model.armed {
          model.disarm()
        } else {
          model.arm(minutes: duration == 0 ? nil : duration)
        }
      } label: {
        HStack {
          Image(systemName: model.armed ? "eye.slash" : "eye.fill")
          Text(model.armed ? "Allow sleep" : "Keep Mac awake")
        }.font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(
          .vertical, 10)
      }.buttonStyle(.plain).background(
        model.armed ? Color.white.opacity(0.08) : accent, in: RoundedRectangle(cornerRadius: 10)
      ).foregroundStyle(model.armed ? .white : .black)
      if !model.sessions.isEmpty {
        VStack(spacing: 9) {
          ForEach(sessionGroups) { group in
            HStack {
              Circle().fill(group.working ? accent : .yellow).frame(width: 5, height: 5)
              Text(group.agent)
              if group.count > 1 {
                Text("×\(group.count)").foregroundStyle(.secondary)
              }
              Spacer()
              Text(group.working ? "Working" : "Waiting").foregroundStyle(.secondary)
            }.font(.system(size: 12))
          }
        }
      }
      Divider()
      HStack {
        Button(action: openSettings) { Label("Settings…", systemImage: "gearshape") }
          .keyboardShortcut(",").buttonStyle(.plain)
        Spacer()
        Button("Quit") {
          model.disarm()
          NSApp.terminate(nil)
        }.buttonStyle(.plain).foregroundStyle(.secondary)
      }.font(.system(size: 12))
    }.padding(22).frame(width: 326).fixedSize(horizontal: false, vertical: true).background(night)
      .preferredColorScheme(.dark)
  }
}
struct SettingsView: View {
  @ObservedObject var model: AppModel
  let tabs = [
    ("Wake", "laptopcomputer"), ("Automation", "bolt"), ("General", "gearshape"),
    ("Activity", "clock"), ("About", "info.circle"),
  ]
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        ForEach(tabs, id: \.0) { name, icon in
          Button {
            model.tab = name
          } label: {
            VStack(spacing: 6) {
              Image(systemName: icon).font(.system(size: 21, weight: .light))
              Text(name).font(.system(size: 11))
            }.foregroundStyle(model.tab == name ? accent : .secondary).frame(width: 78, height: 58)
              .background(
                model.tab == name ? .white.opacity(0.05) : .clear,
                in: RoundedRectangle(cornerRadius: 9)
              ).contentShape(Rectangle())
          }.buttonStyle(.plain)
        }
      }.padding(.vertical, 10).frame(maxWidth: .infinity).background(.white.opacity(0.025))
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if model.showWelcome { welcome }
          switch model.tab {
          case "Wake": arming
          case "Automation": automation
          case "General": general
          case "Activity": activity
          default: about
          }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
      }
    }.frame(width: 510, height: 650).background(night).preferredColorScheme(.dark).tint(accent)
      .alert(
        "Insomnia",
        isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
      ) {
        Button("OK") { model.error = nil }
      } message: {
        Text(model.error ?? "")
      }
  }
  func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
      VStack(spacing: 0, content: content).padding(.horizontal, 13).background(
        .white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
    }
  }
  func toggle(_ text: String, _ binding: Binding<Bool>) -> some View {
    HStack {
      Text(text)
      Spacer()
      Toggle(text, isOn: binding).labelsHidden().toggleStyle(.switch).accessibilityLabel(text)
    }.font(.system(size: 13)).padding(.vertical, 8)
  }
  func slider(
    _ text: String, _ binding: Binding<Double>, range: ClosedRange<Double>, suffix: String
  ) -> some View {
    HStack {
      Text(text).frame(width: 165, alignment: .leading)
      Slider(value: binding, in: range, step: 1)
      Text("\(Int(binding.wrappedValue))\(suffix)").monospacedDigit().frame(
        width: 44, alignment: .trailing
      ).foregroundStyle(.secondary)
    }.font(.system(size: 12)).padding(.vertical, 10)
  }
  var welcome: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack(spacing: 16) {
        Image(systemName: "moon.stars.fill").font(.system(size: 30)).foregroundStyle(accent)
        Text("Close the lid.\nKeep going.").font(
          .system(size: 26, weight: .semibold, design: .rounded))
      }
      Text("Keep a running Mac on a hard, ventilated surface. Never run it inside a bag.").font(
        .system(size: 12)
      ).foregroundStyle(.secondary)
      Button("Get started") { model.finishWelcome() }.buttonStyle(.borderedProminent)
    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(
      accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
  }
  var arming: some View {
    VStack(alignment: .leading, spacing: 18) {
      section("Keep Mac awake") {
        toggle("Hold Fn to keep Mac awake", $model.preferences.fnArming)
        Divider()
        toggle("Play a sound when turned on", $model.preferences.sound)
        HStack {
          Text("Insomnia chime")
          Spacer()
          Button {
            model.playChime()
          } label: {
            Label("Preview", systemImage: "speaker.wave.2")
          }.buttonStyle(.bordered).controlSize(.small)
        }.font(.system(size: 12)).padding(.bottom, 12)
      }
      section("Session") {
        toggle("Keep Mac awake after opening the lid", $model.preferences.stayArmed)
        Divider()
        toggle("Keep awake with the lid open", $model.preferences.keepOpen).disabled(model.armed)
          .help("Allow sleep before changing this setting")
        Divider()
        toggle("Lock screen when lid closes", $model.preferences.lockOnLidClose)
          .help("macOS automatic-lock settings still apply.")
        Text("Leave off so agents can use your Mac’s interface.")
          .font(.system(size: 11)).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true).padding(.bottom, 8)
        if model.preferences.lockOnLidClose {
          HStack {
            Text(
              model.accessibilityTrusted
                ? "Screen lock access enabled" : "Screen lock needs Accessibility")
            Spacer()
            Button(model.accessibilityTrusted ? "Settings…" : "Enable…") {
              model.requestAccessibility()
            }
          }.font(.system(size: 12)).padding(.vertical, 6)
        }
        Divider()
        slider("Maximum session", $model.preferences.maximumHours, range: 1...24, suffix: "h")
      }
      section("Keyboard access") {
        HStack {
          Text(
            CGPreflightListenEventAccess()
              ? "Fn key access enabled" : "Fn key needs Input Monitoring")
          Spacer()
          Button(CGPreflightListenEventAccess() ? "Settings…" : "Enable…") {
            _ = CGRequestListenEventAccess()
            NSWorkspace.shared.open(
              URL(
                string:
                  "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
          }
        }.font(.system(size: 12)).padding(.vertical, 10)

      }
      Button(model.armed ? "Allow sleep" : "Keep Mac awake") {
        if model.armed { model.disarm() } else { model.arm() }
      }.buttonStyle(.borderedProminent)
    }
  }
  var automation: some View {
    VStack(alignment: .leading, spacing: 18) {
      section("Agent sessions") {
        toggle("Turn on while agents are working", $model.preferences.autoArm)
        Divider()
        toggle("Allow sleep when agents finish", $model.preferences.autoStop)
        Divider()
        toggle("Keep on while agents wait for approval", $model.preferences.keepWaiting)
      }
      section("Connections") {
        ForEach(Integration.all) { item in
          HStack(spacing: 12) {
            Image(
              systemName: item.name == "Claude Code"
                ? "asterisk"
                : item.name == "Codex"
                  ? "terminal"
                  : item.name == "Cursor"
                    ? "cursorarrow" : "chevron.left.forwardslash.chevron.right"
            ).font(.system(size: 18)).frame(width: 25)
            Text(item.name)
            Spacer()
            Button(model.connected.contains(item.name) ? "Disconnect" : "Connect") {
              model.connect(item)
            }.buttonStyle(.bordered).controlSize(.small)
          }.font(.system(size: 13)).padding(.vertical, 10)
          if item.name != "OpenCode" { Divider() }
        }
      }
      Text(
        "Restart connected agents after installing hooks. Codex requires reviewing and trusting them in /hooks. ChatGPT has no public local lifecycle hook."
      ).font(.system(size: 12)).foregroundStyle(.secondary)
    }
  }
  var general: some View {
    VStack(alignment: .leading, spacing: 18) {
      section("Behavior") {
        toggle("Open at login", Binding(get: { model.login }, set: { model.setLogin($0) }))
      }
      section("Safety") {
        toggle("Allow sleep on low battery", $model.preferences.batteryGuard)
        slider("Low battery level", $model.preferences.batteryLimit, range: 5...50, suffix: "%")
          .disabled(!model.preferences.batteryGuard)
        Divider()
        toggle("Stop if the Mac overheats", $model.preferences.thermalGuard)
        Divider()
        toggle("Use a battery temperature limit", $model.preferences.temperatureGuard)
        slider(
          "Temperature limit", $model.preferences.temperatureLimit, range: 35...50, suffix: "°C"
        ).disabled(!model.preferences.temperatureGuard)
      }
      section("Support") {
        HStack {
          Button {
            model.copyDiagnostics()
          } label: {
            Label("Copy diagnostics", systemImage: "doc.on.doc")
          }
          Spacer()
          Button("Replay welcome") {
            model.showWelcome = true
            model.tab = "Wake"
          }
        }.padding(.vertical, 10)
      }
    }
  }
  var activity: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Recent activity").font(.system(size: 17, weight: .semibold))
        Spacer()
        Button("Clear") { model.history = [] }
      }
      if model.history.isEmpty {
        Text("No sessions yet").foregroundStyle(.secondary).padding(.vertical, 30)
      }
      ForEach(Array(model.history.enumerated()), id: \.offset) { _, entry in
        Text(entry).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).padding(
          .vertical, 5)
        Divider()
      }
    }
  }
  var about: some View {
    VStack(spacing: 18) {
      InsomniaMark(active: true).padding(.top, 15)
      Text("Insomnia").font(.system(size: 27, weight: .semibold, design: .rounded))
      Text("Version 1.0").font(.system(size: 12)).foregroundStyle(.secondary)
      Divider().padding(.vertical, 10)
      HStack {
        Text("Licence")
        Spacer()
        Text("Free · Open source").foregroundStyle(.secondary)
      }.font(.system(size: 13))
    }.frame(maxWidth: .infinity)
  }
}
struct ArmingOverlay: View {
  var body: some View {
    ZStack {
      Color.black.opacity(0.97)
      VStack(spacing: 28) {
        Image(systemName: "moon.stars.fill").font(.system(size: 110, weight: .ultraLight))
          .foregroundStyle(accent).shadow(color: accent.opacity(0.4), radius: 55)
        Text("Close the lid.").font(.system(size: 52, weight: .light, design: .rounded))
        Text("Release Fn to dismiss").font(.system(size: 13)).foregroundStyle(.secondary)
      }
    }.background(night).preferredColorScheme(.dark)
  }
}
