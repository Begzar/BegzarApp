import FlutterMacOS
import Foundation
import LocalAuthentication

/// macOS system proxy + explicit user-presence confirmation.
///
/// Admin password is requested **once per app session**: a long-lived
/// `osascript` process keeps a root worker running. setProxy/clearProxy then
/// exchange commands via files in a private temp dir (no extra prompts).
final class SystemProxyPlugin: NSObject {
  private static var appliedByUs = false
  private static var previousByService: [String: ServiceProxySnapshot] = [:]
  private static var appliedServices: [String] = []

  private static let workerLock = NSLock()
  private static var workerProcess: Process?
  private static var workerToken: String?
  private static var workerDir: String?
  private static var cmdFilePath: String?
  private static var rspFilePath: String?

  private struct ServiceProxySnapshot {
    let webEnabled: Bool
    let webHost: String
    let webPort: String
    let secureEnabled: Bool
    let secureHost: String
    let securePort: String
    let bypassDomains: String
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "begzar/system_proxy",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "requestUserPresence":
        let reason =
          (call.arguments as? [String: Any])?["reason"] as? String
          ?? "Begzar needs permission to continue."
        requestUserPresence(reason: reason, result: result)

      case "setProxy":
        guard
          let args = call.arguments as? [String: Any],
          let host = args["host"] as? String,
          let port = intValue(args["port"])
        else {
          result(
            FlutterError(
              code: "bad_args",
              message: "host/port required",
              details: nil
            )
          )
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let ok = applyProxy(host: host, port: port)
          DispatchQueue.main.async { result(ok) }
        }

      case "clearProxy":
        DispatchQueue.global(qos: .userInitiated).async {
          let ok = clearProxy()
          DispatchQueue.main.async { result(ok) }
        }

      case "probeAccess":
        DispatchQueue.global(qos: .userInitiated).async {
          let ok = probeAccess()
          DispatchQueue.main.async { result(ok) }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification,
      object: nil,
      queue: nil
    ) { _ in
      shutdownPrivilegedWorker()
    }
  }

  // MARK: - Local Authentication

  private static func requestUserPresence(
    reason: String,
    result: @escaping FlutterResult
  ) {
    let context = LAContext()
    var error: NSError?
    let policy = LAPolicy.deviceOwnerAuthentication
    guard context.canEvaluatePolicy(policy, error: &error) else {
      result(false)
      return
    }
    context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
      if let evalError {
      }
      DispatchQueue.main.async { result(success) }
    }
  }

  private static func intValue(_ raw: Any?) -> Int? {
    if let v = raw as? Int { return v }
    if let v = raw as? Int64 { return Int(v) }
    if let v = raw as? NSNumber { return v.intValue }
    return nil
  }

  // MARK: - Proxy apply / clear / probe

  private static func applyProxy(host: String, port: Int) -> Bool {
    let services = hardwareNetworkServices()
    guard !services.isEmpty else { return false }

    if !appliedByUs {
      previousByService.removeAll()
      appliedServices.removeAll()
      for service in services {
        previousByService[service] = snapshot(for: service)
      }
    }

    let portStr = String(port)
    var commands: [String] = []
    for service in services {
      let q = shellQuote(service)
      commands.append(
        "/usr/sbin/networksetup -setwebproxy \(q) \(shellQuote(host)) \(portStr)"
      )
      commands.append(
        "/usr/sbin/networksetup -setsecurewebproxy \(q) \(shellQuote(host)) \(portStr)"
      )
      commands.append(
        "/usr/sbin/networksetup -setproxybypassdomains \(q) 127.0.0.1 localhost '*.local' 169.254.0.0/16"
      )
    }

    guard runCommandsRequiringAdmin(commands) else { return false }

    let primary = services[0]
    let web = parseProxyGet(runNetworkSetupCapture(["-getwebproxy", primary]))
    let ok = web.enabled && web.host == host && web.port == portStr
    if ok {
      appliedByUs = true
      appliedServices = services
    }
    return ok
  }

  private static func probeAccess() -> Bool {
    let services = hardwareNetworkServices()
    guard let service = services.first else { return false }

    guard ensurePrivilegedWorker() else { return false }

    let before = snapshot(for: service)
    let q = shellQuote(service)
    let probeHost = "127.0.0.1"
    let probePort = "9"

    var commands: [String] = [
      "/usr/sbin/networksetup -setwebproxy \(q) \(shellQuote(probeHost)) \(probePort)",
      "/usr/sbin/networksetup -setsecurewebproxy \(q) \(shellQuote(probeHost)) \(probePort)",
    ]

    if before.webEnabled {
      commands.append(
        "/usr/sbin/networksetup -setwebproxy \(q) \(shellQuote(before.webHost)) \(shellQuote(before.webPort))"
      )
      commands.append("/usr/sbin/networksetup -setwebproxystate \(q) on")
    } else {
      commands.append("/usr/sbin/networksetup -setwebproxystate \(q) off")
    }
    if before.secureEnabled {
      commands.append(
        "/usr/sbin/networksetup -setsecurewebproxy \(q) \(shellQuote(before.secureHost)) \(shellQuote(before.securePort))"
      )
      commands.append("/usr/sbin/networksetup -setsecurewebproxystate \(q) on")
    } else {
      commands.append("/usr/sbin/networksetup -setsecurewebproxystate \(q) off")
    }

    return runCommandsRequiringAdmin(commands)
  }

  private static func clearProxy() -> Bool {
    guard appliedByUs else { return true }

    var commands: [String] = []
    for service in appliedServices {
      guard let snap = previousByService[service] else { continue }
      let q = shellQuote(service)
      if snap.webEnabled {
        commands.append(
          "/usr/sbin/networksetup -setwebproxy \(q) \(shellQuote(snap.webHost)) \(shellQuote(snap.webPort))"
        )
        commands.append("/usr/sbin/networksetup -setwebproxystate \(q) on")
      } else {
        commands.append("/usr/sbin/networksetup -setwebproxystate \(q) off")
      }
      if snap.secureEnabled {
        commands.append(
          "/usr/sbin/networksetup -setsecurewebproxy \(q) \(shellQuote(snap.secureHost)) \(shellQuote(snap.securePort))"
        )
        commands.append("/usr/sbin/networksetup -setsecurewebproxystate \(q) on")
      } else {
        commands.append("/usr/sbin/networksetup -setsecurewebproxystate \(q) off")
      }
    }

    let ok = commands.isEmpty ? true : runCommandsRequiringAdmin(commands)
    appliedByUs = false
    previousByService.removeAll()
    appliedServices.removeAll()
    return ok
  }

  // MARK: - Privileged session worker (one password prompt)

  @discardableResult
  private static func runCommandsRequiringAdmin(_ commands: [String]) -> Bool {
    guard !commands.isEmpty else { return true }
    guard ensurePrivilegedWorker() else { return false }
    return runPrivilegedShell(commands.joined(separator: " && "))
  }

  private static func ensurePrivilegedWorker() -> Bool {
    workerLock.lock()
    defer { workerLock.unlock() }

    if isWorkerAlive() {
      return true
    }
    teardownWorkerLocked()

    let dir = (NSTemporaryDirectory() as NSString)
      .appendingPathComponent("begzar-proxy-\(getuid())-\(UUID().uuidString)")
    let cmdFile = (dir as NSString).appendingPathComponent("cmd")
    let rspFile = (dir as NSString).appendingPathComponent("rsp")
    let readyFile = (dir as NSString).appendingPathComponent("ready")
    let scriptPath = (dir as NSString).appendingPathComponent("worker.sh")
    let token = UUID().uuidString

    do {
      try FileManager.default.createDirectory(
        atPath: dir,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
      )

      // World-accessible dir bits only for this private folder; cmd/rsp are
      // created by the root worker / app with explicit token auth.
      let workerBash = """
      #!/bin/bash
      set +e
      CMD_FILE=\(shellQuote(cmdFile))
      RSP_FILE=\(shellQuote(rspFile))
      READY_FILE=\(shellQuote(readyFile))
      TOKEN=\(shellQuote(token))
      umask 022
      printf '1\\n' > "$READY_FILE"
      chmod 666 "$READY_FILE" 2>/dev/null || true
      while true; do
        if [[ ! -f "$CMD_FILE" ]]; then
          sleep 0.05
          continue
        fi
        # Wait until writer finishes (atomic replace from app side).
        sleep 0.02
        line=$(cat "$CMD_FILE" 2>/dev/null)
        rm -f "$CMD_FILE"
        case "$line" in
          "$TOKEN|"*)
            cmd="${line#*|}"
            ;;
          *)
            printf 'auth\\n' > "$RSP_FILE"
            chmod 666 "$RSP_FILE" 2>/dev/null || true
            continue
            ;;
        esac
        case "$cmd" in
          __BEGZAR_PING__)
            printf '0\\n' > "$RSP_FILE"
            chmod 666 "$RSP_FILE" 2>/dev/null || true
            continue
            ;;
          __BEGZAR_QUIT__)
            printf '0\\n' > "$RSP_FILE"
            chmod 666 "$RSP_FILE" 2>/dev/null || true
            exit 0
            ;;
          /usr/sbin/networksetup*)
            /bin/bash -c "$cmd"
            printf '%s\\n' "$?" > "$RSP_FILE"
            chmod 666 "$RSP_FILE" 2>/dev/null || true
            ;;
          *)
            printf 'denied\\n' > "$RSP_FILE"
            chmod 666 "$RSP_FILE" 2>/dev/null || true
            ;;
        esac
      done
      """
      try workerBash.write(toFile: scriptPath, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: scriptPath
      )
    } catch {
      return false
    }

    // Keep osascript alive for the session — one admin dialog, then worker runs
    // in the foreground under that elevated shell (no nohup race).
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = [
      "-e",
      "do shell script \"exec /bin/bash \(shellQuote(scriptPath))\" with administrator privileges",
    ]
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
      try process.run()
    } catch {
      teardownWorkerLocked()
      return false
    }

    workerProcess = process
    workerDir = dir
    cmdFilePath = cmdFile
    rspFilePath = rspFile
    workerToken = token

    workerLock.unlock()
    let ready = waitForFile(readyFile, timeoutSeconds: 120)
    let pingOk = ready && runPrivilegedShell("__BEGZAR_PING__")
    workerLock.lock()

    if !pingOk || !isWorkerAlive() {
      shutdownPrivilegedWorkerLocked()
      return false
    }

    return true
  }

  private static func runPrivilegedShell(_ command: String) -> Bool {
    workerLock.lock()
    let cmdPath = cmdFilePath
    let rspPath = rspFilePath
    let token = workerToken
    let alive = isWorkerAlive()
    workerLock.unlock()

    guard alive, let cmdPath, let rspPath, let token else { return false }

    let payload = "\(token)|\(command)\n"
    try? FileManager.default.removeItem(atPath: rspPath)

    // Atomic-ish write: write temp then move into place.
    let tmp = cmdPath + ".tmp"
    do {
      try payload.write(toFile: tmp, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o666],
        ofItemAtPath: tmp
      )
      // Root worker must be able to read — chmod dir/files accordingly.
      if FileManager.default.fileExists(atPath: cmdPath) {
        try? FileManager.default.removeItem(atPath: cmdPath)
      }
      try FileManager.default.moveItem(atPath: tmp, toPath: cmdPath)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o666],
        ofItemAtPath: cmdPath
      )
    } catch {
      return false
    }

    guard let response = waitForResponse(at: rspPath, timeoutSeconds: 30) else {
      return false
    }

    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed == "0" { return true }
    return false
  }

  private static func waitForFile(_ path: String, timeoutSeconds: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
      if FileManager.default.fileExists(atPath: path) {
        return true
      }
      // User may still be typing the admin password.
      if !isWorkerAlive() {
        // Process may still be showing the auth dialog (osascript not exited).
        // Only fail early if it already terminated.
        if let p = workerProcess, !p.isRunning {
          return false
        }
      }
      Thread.sleep(forTimeInterval: 0.1)
    }
    return FileManager.default.fileExists(atPath: path)
  }

  private static func waitForResponse(
    at path: String,
    timeoutSeconds: TimeInterval
  ) -> String? {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
      if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
        let text = String(data: data, encoding: .utf8),
        !text.isEmpty
      {
        try? FileManager.default.removeItem(atPath: path)
        return text
      }
      Thread.sleep(forTimeInterval: 0.05)
    }
    return nil
  }

  private static func isWorkerAlive() -> Bool {
    workerProcess?.isRunning == true
  }

  static func shutdownPrivilegedWorker() {
    workerLock.lock()
    shutdownPrivilegedWorkerLocked()
    workerLock.unlock()
  }

  private static func shutdownPrivilegedWorkerLocked() {
    if isWorkerAlive(), let token = workerToken, let cmdPath = cmdFilePath {
      let payload = "\(token)|__BEGZAR_QUIT__\n"
      let tmp = cmdPath + ".tmp"
      try? payload.write(toFile: tmp, atomically: true, encoding: .utf8)
      try? FileManager.default.removeItem(atPath: cmdPath)
      try? FileManager.default.moveItem(atPath: tmp, toPath: cmdPath)
      // Give worker a moment to exit cleanly.
      let deadline = Date().addingTimeInterval(1.5)
      while Date() < deadline, isWorkerAlive() {
        Thread.sleep(forTimeInterval: 0.05)
      }
    }
    if let process = workerProcess, process.isRunning {
      process.terminate()
    }
    teardownWorkerLocked()
  }

  private static func teardownWorkerLocked() {
    if let dir = workerDir {
      try? FileManager.default.removeItem(atPath: dir)
    }
    workerDir = nil
    cmdFilePath = nil
    rspFilePath = nil
    workerToken = nil
    workerProcess = nil
  }

  // MARK: - Network service discovery

  private static func hardwareNetworkServices() -> [String] {
    let order = runNetworkSetupCapture(["-listnetworkserviceorder"])
    var result: [String] = []
    let blocks = order.components(separatedBy: "\n\n")
    for block in blocks {
      let lines = block
        .split(separator: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
      guard let nameLine = lines.first(where: { $0.hasPrefix("(") }) else {
        continue
      }
      if nameLine.hasPrefix("(*)") { continue }

      guard
        let hardwareLine = lines.first(where: { $0.contains("Hardware Port:") })
      else { continue }

      guard
        let deviceRange = hardwareLine.range(of: "Device:"),
        case let device = String(hardwareLine[deviceRange.upperBound...])
          .trimmingCharacters(in: CharacterSet(charactersIn: " )")),
        !device.isEmpty,
        device.hasPrefix("en") || device.hasPrefix("bridge") || device.hasPrefix("eth")
      else {
        continue
      }

      let name = nameLine
        .replacingOccurrences(
          of: #"^\(\d+\)\s*"#,
          with: "",
          options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if !name.isEmpty {
        result.append(name)
      }
    }

    result.sort { a, b in
      let score: (String) -> Int = { name in
        let lower = name.lowercased()
        if lower.contains("wi-fi") || lower.contains("wifi") { return 0 }
        if lower.contains("ethernet") { return 1 }
        if lower.contains("usb") { return 2 }
        return 3
      }
      return score(a) < score(b)
    }
    return result
  }

  private static func snapshot(for service: String) -> ServiceProxySnapshot {
    let web = parseProxyGet(runNetworkSetupCapture(["-getwebproxy", service]))
    let secure = parseProxyGet(
      runNetworkSetupCapture(["-getsecurewebproxy", service])
    )
    let bypass = runNetworkSetupCapture(["-getproxybypassdomains", service])
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return ServiceProxySnapshot(
      webEnabled: web.enabled,
      webHost: web.host,
      webPort: web.port,
      secureEnabled: secure.enabled,
      secureHost: secure.host,
      securePort: secure.port,
      bypassDomains: bypass
    )
  }

  private static func parseProxyGet(_ output: String) -> (
    enabled: Bool, host: String, port: String
  ) {
    var enabled = false
    var host = ""
    var port = "0"
    for line in output.split(separator: "\n") {
      let parts = line.split(separator: ":", maxSplits: 1).map {
        $0.trimmingCharacters(in: .whitespaces)
      }
      guard parts.count == 2 else { continue }
      switch parts[0] {
      case "Enabled":
        enabled = parts[1].lowercased() == "yes"
      case "Server":
        host = parts[1]
      case "Port":
        port = parts[1]
      default:
        break
      }
    }
    return (enabled, host, port)
  }

  private static func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }

  private static func runNetworkSetupCapture(_ args: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    process.arguments = args
    let out = Pipe()
    process.standardOutput = out
    process.standardError = Pipe()
    do {
      try process.run()
      process.waitUntilExit()
      let data = out.fileHandleForReading.readDataToEndOfFile()
      return String(data: data, encoding: .utf8) ?? ""
    } catch {
      return ""
    }
  }
}
