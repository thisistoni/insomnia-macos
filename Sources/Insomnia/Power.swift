import Foundation
import IOKit
import IOKit.pwr_mgt
import InsomniaCore

func registryProperties(_ name: String) -> [String: Any] {
  let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(name))
  guard service != 0 else { return [:] }
  defer { IOObjectRelease(service) }
  var properties: Unmanaged<CFMutableDictionary>?
  guard
    IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS
  else { return [:] }
  return properties?.takeRetainedValue() as? [String: Any] ?? [:]
}
func readSensors() -> Sensors {
  let b = registryProperties("AppleSmartBattery")
  let raw = (b["Temperature"] as? NSNumber)?.doubleValue
  // AppleSmartBattery reports temperature in tenths of a kelvin.
  let celsius = raw.map { $0 / 10 - 273.15 }
  return Sensors(
    battery: (b["CurrentCapacity"] as? NSNumber)?.doubleValue,
    charging: b["ExternalConnected"] as? Bool ?? false,
    temperature: celsius.flatMap { (-10...100).contains($0) ? $0 : nil },
    thermal: ProcessInfo.processInfo.thermalState.rawValue)
}
final class PowerControl {
  private let ownershipLock = NSRecursiveLock()
  var connection: io_connect_t = 0
  var assertion: IOPMAssertionID = 0
  var ownsLid = false
  func arm(keepOpen: Bool) throws {
    ownershipLock.lock()
    defer { ownershipLock.unlock() }
    let service = IOServiceGetMatchingService(
      kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard service != 0 else { throw PowerError.failed("No Mac power controller found") }
    defer { IOObjectRelease(service) }
    let opened = IOServiceOpen(service, mach_task_self_, 0, &connection)
    guard opened == KERN_SUCCESS else { throw PowerError.failed("Lid control denied (\(opened))") }
    var input: UInt64 = 1
    let result = IOConnectCallScalarMethod(connection, 12, &input, 1, nil, nil)
    guard result == KERN_SUCCESS else {
      release()
      throw PowerError.failed("Lid control unavailable (\(result))")
    }
    ownsLid = true
    try? Data("owned".utf8).write(
      to: Paths.support.appendingPathComponent("power-owned"), options: .atomic)
    if keepOpen {
      let status = IOPMAssertionCreateWithName(
        kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Insomnia active session" as CFString, &assertion
      )
      guard status == kIOReturnSuccess else {
        release()
        throw PowerError.failed("Sleep assertion failed (\(status))")
      }
    }
  }
  /// powerd may reevaluate the shared clamshell flag after power-source/display changes.
  func refreshLid() throws {
    ownershipLock.lock()
    defer { ownershipLock.unlock() }
    guard ownsLid, connection != 0 else { return }
    var input: UInt64 = 1
    let result = IOConnectCallScalarMethod(connection, 12, &input, 1, nil, nil)
    guard result == KERN_SUCCESS else {
      throw PowerError.failed("Lid control stopped (\(result))")
    }
  }

  func release() {
    ownershipLock.lock()
    defer { ownershipLock.unlock() }
    if assertion != 0 {
      IOPMAssertionRelease(assertion)
      assertion = 0
    }
    if ownsLid && connection != 0 {
      var input: UInt64 = 0
      let restored = IOConnectCallScalarMethod(connection, 12, &input, 1, nil, nil)
      ownsLid = false
      // Retain the receipt if the kernel rejected restoration so a later launch retries.
      if restored == KERN_SUCCESS {
        try? FileManager.default.removeItem(at: Paths.support.appendingPathComponent("power-owned"))
      }
    }
    if connection != 0 {
      IOServiceClose(connection)
      connection = 0
    }
  }
  static func recoverIfNeeded() {
    let marker = Paths.support.appendingPathComponent("power-owned")
    guard FileManager.default.fileExists(atPath: marker.path) else { return }
    let p = PowerControl()
    let service = IOServiceGetMatchingService(
      kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard service != 0 else { return }
    defer { IOObjectRelease(service) }
    if IOServiceOpen(service, mach_task_self_, 0, &p.connection) == KERN_SUCCESS {
      p.ownsLid = true
      p.release()
    }
  }
  deinit { release() }
}
enum PowerError: LocalizedError {
  case failed(String)
  var errorDescription: String? {
    if case .failed(let s) = self { return s }
    return nil
  }
}
// The parent sends a heartbeat every half second. EOF, a hung parent, or its death restores lid behavior.
func runPowerHelper() -> Never {
  let power = PowerControl()
  do {
    try power.arm(keepOpen: !CommandLine.arguments.contains("--allow-idle"))
    print("READY")
    fflush(stdout)
  } catch {
    print("ERROR \(error.localizedDescription)")
    fflush(stdout)
    exit(1)
  }
  let parent = getppid()
  var lastBeat = Date()
  let queue = DispatchQueue(label: "power-watchdog")
  let timer = DispatchSource.makeTimerSource(queue: queue)
  timer.schedule(deadline: .now() + 1, repeating: 1)
  let lock = NSLock()
  timer.setEventHandler {
    lock.lock()
    let expired = Date().timeIntervalSince(lastBeat) > 5
    lock.unlock()
    if expired || getppid() != parent {
      power.release()
      exit(0)
    }
  }
  timer.resume()
  signal(SIGTERM, SIG_IGN)
  signal(SIGINT, SIG_IGN)
  let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: queue)
  let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: queue)
  term.setEventHandler {
    power.release()
    exit(0)
  }
  interrupt.setEventHandler {
    power.release()
    exit(0)
  }
  term.resume()
  interrupt.resume()
  while let line = readLine() {
    if line == "STOP" { break }
    guard line == "BEAT" else { continue }
    do { try power.refreshLid() } catch {
      power.release()
      exit(1)
    }
    lock.lock()
    lastBeat = Date()
    lock.unlock()
  }
  timer.cancel()
  power.release()
  exit(0)
}
