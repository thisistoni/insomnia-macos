import AppKit
import Combine
import IOKit.pwr_mgt
import SwiftUI

if CommandLine.arguments.contains("--power-helper") { runPowerHelper() }
if CommandLine.arguments.contains("--stillon-hook") {
  sendHook()
  exit(0)
}
if CommandLine.arguments.contains("--refresh-connections") {
  do {
    for integration in Integration.all where integration.installed() {
      try integration.setInstalled(true)
      print("Updated \(integration.name)")
    }
    exit(0)
  } catch {
    print(error.localizedDescription)
    exit(1)
  }
}
if CommandLine.arguments.contains("--probe") {
  let power = PowerControl()
  do {
    try power.arm(keepOpen: true)
    let root = registryProperties("IOPMrootDomain")
    print(
      "Lid API accepted; assertion ID: \(power.assertion); causes sleep: \(root["AppleClamshellCausesSleep"] ?? "unknown")"
    )
    power.release()
    print("Restored normal power behavior")
    exit(0)
  } catch {
    print(error.localizedDescription)
    exit(1)
  }
}
// A second GUI instance must not recover power ownership from the running one.
if let identifier = Bundle.main.bundleIdentifier,
  NSRunningApplication.runningApplications(withBundleIdentifier: identifier).contains(where: {
    $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
  })
{
  exit(0)
}

@MainActor final class SettingsHostingView: NSHostingView<SettingsView> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
  let model = AppModel()
  var status: NSStatusItem!
  let popover = NSPopover()
  var window: NSWindow?
  var overlay: NSWindow?
  var observer: Any?
  var layoutObserver: Any?
  var outsideClickMonitor: Any?
  var localClickMonitor: Any?
  var activationObserver: NSObjectProtocol?
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    status.button?.image = NSImage(
      systemSymbolName: "eye.slash", accessibilityDescription: "Insomnia — sleep allowed")
    status.button?.target = self
    status.button?.action = #selector(statusClicked)
    status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    popover.behavior = .transient
    popover.delegate = self
    activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] note in
      guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
        app.processIdentifier != ProcessInfo.processInfo.processIdentifier
      else { return }
      Task { @MainActor [weak self] in self?.popover.performClose(nil) }
    }
    let panelController = NSHostingController(
      rootView: PanelView(model: model, openSettings: { [weak self] in self?.openSettings() }))
    panelController.sizingOptions = []
    popover.contentViewController = panelController
    popover.contentSize = panelController.sizeThatFits(in: NSSize(width: 326, height: 10_000))
    model.showOverlay = { [weak self] in self?.displayOverlay() }
    model.hideOverlay = { [weak self] in self?.overlay?.orderOut(nil) }
    observer = model.$armed.sink { [weak self] value in
      let description = value ? "Insomnia — keeping Mac awake" : "Insomnia — sleep allowed"
      self?.status?.button?.image = NSImage(
        systemSymbolName: value ? "eye.fill" : "eye.slash", accessibilityDescription: description)
      self?.status?.button?.image?.isTemplate = true
      self?.status?.button?.toolTip = description
      self?.status?.button?.setAccessibilityLabel(description)
    }
    layoutObserver = model.objectWillChange.sink { [weak self] _ in
      DispatchQueue.main.async {
        guard let self, self.popover.isShown else { return }
        self.resizePopover()
      }
    }
    if let index = CommandLine.arguments.firstIndex(of: "--export-panel"),
      CommandLine.arguments.indices.contains(index + 1)
    {
      let path = CommandLine.arguments[index + 1]
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
        guard let self else { return }
        let controller = NSHostingController(
          rootView: PanelView(model: self.model, openSettings: {}))
        controller.sizingOptions = []
        let size = controller.sizeThatFits(in: NSSize(width: 326, height: 10_000))
        let captureWindow = NSWindow(
          contentRect: NSRect(origin: .zero, size: size),
          styleMask: [.borderless], backing: .buffered, defer: false)
        captureWindow.contentViewController = controller
        controller.view.frame = NSRect(origin: .zero, size: size)
        captureWindow.orderFrontRegardless()
        controller.view.layoutSubtreeIfNeeded()
        controller.view.displayIfNeeded()
        if let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds)
        {
          controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
          if let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
          }
        }
        NSApp.terminate(nil)
      }
      return
    }
    if model.showWelcome || CommandLine.arguments.contains("--settings") { openSettings() }
    if CommandLine.arguments.contains("--quick-menu") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.showQuickMenu() }
    }
    if CommandLine.arguments.contains("--panel") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.togglePopover() }
    }
  }
  @objc func statusClicked() {
    if NSApp.currentEvent?.type == .rightMouseUp { showQuickMenu() } else { togglePopover() }
  }
  func showQuickMenu() {
    popover.performClose(nil)
    guard let button = status.button else { return }
    let menu = NSMenu()
    let power = NSMenuItem(
      title: model.armed ? "Allow sleep" : "Keep Mac awake", action: #selector(togglePower),
      keyEquivalent: "")
    power.target = self
    power.image = NSImage(
      systemSymbolName: model.armed ? "power" : "eye", accessibilityDescription: nil)
    menu.addItem(power)
    menu.addItem(.separator())
    let settings = NSMenuItem(
      title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
    settings.target = self
    settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
    menu.addItem(settings)
    let quit = NSMenuItem(title: "Quit Insomnia", action: #selector(quitApp), keyEquivalent: "q")
    quit.target = self
    menu.addItem(quit)
    menu.popUp(
      positioning: nil, at: NSPoint(x: button.bounds.minX, y: button.bounds.minY), in: button)
  }
  @objc func togglePower() { if model.armed { model.disarm() } else { model.arm() } }
  @objc func showSettings() { openSettings() }
  @objc func quitApp() {
    model.disarm()
    NSApp.terminate(nil)
  }
  func startDismissalMonitoring() {
    stopDismissalMonitoring()
    outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]) { [weak self] _ in
      Task { @MainActor [weak self] in self?.popover.performClose(nil) }
    }
    localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]) { [weak self] event in
      guard let self else { return event }
      let panelWindow = self.popover.contentViewController?.view.window
      if event.window !== panelWindow && event.window !== self.status.button?.window {
        self.popover.performClose(nil)
      }
      return event
    }
  }
  func stopDismissalMonitoring() {
    if let outsideClickMonitor {
      NSEvent.removeMonitor(outsideClickMonitor)
      self.outsideClickMonitor = nil
    }
    if let localClickMonitor {
      NSEvent.removeMonitor(localClickMonitor)
      self.localClickMonitor = nil
    }
  }
  func popoverDidClose(_ notification: Notification) { stopDismissalMonitoring() }
  @objc func togglePopover() {
    if popover.isShown {
      popover.performClose(nil)
    } else if let button = status.button {
      resizePopover()
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      startDismissalMonitoring()
    }
  }
  func resizePopover() {
    guard let controller = popover.contentViewController as? NSHostingController<PanelView> else {
      return
    }
    let measured = controller.sizeThatFits(in: NSSize(width: 326, height: 10_000))
    let size = NSSize(width: 326, height: ceil(measured.height))
    if popover.contentSize != size { popover.contentSize = size }
  }
  func openSettings() {
    popover.performClose(nil)
    if window == nil {
      let w = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 510, height: 650),
        styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
      w.title = "Insomnia"
      w.titlebarAppearsTransparent = true
      w.isReleasedWhenClosed = false
      w.contentView = SettingsHostingView(rootView: SettingsView(model: model))
      w.center()
      window = w
    }
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }
  func displayOverlay() {
    guard let screen = NSScreen.main else { return }
    if overlay == nil {
      let w = NSWindow(
        contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
      w.level = .screenSaver
      w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      w.ignoresMouseEvents = true
      w.contentView = NSHostingView(rootView: ArmingOverlay())
      overlay = w
    }
    overlay?.setFrame(screen.frame, display: true)
    overlay?.orderFrontRegardless()
  }
  func applicationWillTerminate(_ notification: Notification) {
    stopDismissalMonitoring()
    model.disarm()
  }
}
MainActor.assumeIsolated {
  let app = NSApplication.shared
  let delegate = AppDelegate()
  app.delegate = delegate
  app.run()
}
