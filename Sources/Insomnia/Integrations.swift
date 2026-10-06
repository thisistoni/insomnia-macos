import Foundation
import InsomniaCore

enum Paths {
  static var support: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Application Support/StillOnClone")
  }
  static var events: URL { support.appendingPathComponent("events") }
  static func prepare() throws {
    try FileManager.default.createDirectory(
      at: events, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  }
}
func sendHook() {
  guard CommandLine.arguments.count >= 4 else { return }
  let agent = CommandLine.arguments[2]
  let state = CommandLine.arguments[3]
  let input = FileHandle.standardInput.readDataToEndOfFile()
  let json = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] ?? [:]
  guard let session = json["session_id"] as? String ?? json["conversation_id"] as? String,
    !session.isEmpty, session.count < 256
  else { return }
  // Only lifecycle metadata survives; prompts, paths, and tool arguments are discarded.
  do {
    try Paths.prepare()
    let event = AgentEvent(agent: agent, session: session, state: state)
    let file = Paths.events.appendingPathComponent(UUID().uuidString + ".json")
    try JSONEncoder().encode(event).write(to: file, options: .atomic)
  } catch {
    // A hook must never interrupt the agent.
  }
}
struct Integration: Identifiable {
  let name: String
  let folder: String
  let config: String
  var id: String { name }
  var url: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(folder)
      .appendingPathComponent(config)
  }
  static let all = [
    Integration(name: "Claude Code", folder: ".claude", config: "settings.json"),
    Integration(name: "Codex", folder: ".codex", config: "hooks.json"),
    Integration(name: "Cursor", folder: ".cursor", config: "hooks.json"),
    Integration(name: "OpenCode", folder: ".config/opencode/plugins", config: "stillon-clone.js"),
  ]
  func installed() -> Bool {
    guard let text = try? String(contentsOf: url) else { return false }
    return text.contains("--stillon-hook")
  }
  func setInstalled(_ install: Bool) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let old = try? Data(contentsOf: url)
    if let old {
      try old.write(
        to: url.appendingPathExtension("backup-\(Int(Date().timeIntervalSince1970))"),
        options: .atomic)
    }
    let executable = Bundle.main.executablePath ?? CommandLine.arguments[0]
    if name == "OpenCode" {
      if !install {
        if installed() { try fm.removeItem(at: url) }
        return
      }
      let encoded = String(data: try JSONEncoder().encode(executable), encoding: .utf8)!
      let plugin = """
        // Insomnia --stillon-hook lifecycle bridge
        import { spawn } from 'node:child_process';
        export const StillOnClone = async () => ({
          event: async ({ event }) => {
            const p = event.properties || {};
            const id = p.sessionID || p.info?.id;
            if (!id) return;
            let state;
            if (event.type === 'session.status') state = p.status?.type === 'idle' ? 'finished' : 'working';
            if (['session.idle','session.deleted','session.error'].includes(event.type)) state = 'finished';
            if (event.type === 'permission.asked') state = 'waiting';
            if (event.type === 'permission.replied') state = 'working';
            if (!state) return;
            const child = spawn(\(encoded), ['--stillon-hook', 'OpenCode', state], { stdio: ['pipe', 'ignore', 'ignore'] });
            child.on('error', () => {});
            child.stdin.on('error', () => {});
            child.stdin.end(JSON.stringify({ session_id: id }));
          }
        });
        """
      try Data(plugin.utf8).write(to: url, options: .atomic)
    } else {
      let updated = try HookConfig.update(
        old, agent: name, executable: executable, installing: install)
      try updated.write(to: url, options: .atomic)
    }
  }
}
