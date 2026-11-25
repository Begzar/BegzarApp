import NetworkExtension
import Tun2SocksKit
import BegzarEngineKit
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    private static let appGroupId = "group.cloud.begzar.begzarvpnG"

    /// Engine launches, one at a time, in the order the app sent them.
    private static let launchQueue = DispatchQueue(
        label: "BegzarEngineTunnel.launch", qos: .userInitiated)

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BegzarEngineTunnel",
        category: "TunnelProvider")

    private struct TunnelDefaults {
        static let port: Int32 = 2080
        static let address = "127.0.0.1"
        static let mtu = 1500
        
        static let tunnelAddress = "127.0.0.1"
        static let tunnelIpv4 = "198.18.0.1"
        static let tunnelIpv4Mask = "255.255.255.0"
        static let tunnelIpv6 = "fc00::1"
        static let tunnelIpv6PrefixLength = 64
        // The engine forwards each query sent to these to the DNS server its
        // config names, so they never have to be reachable. They stay public
        // addresses off the engine's Direct list all the same: a query it
        // failed to catch would go through the proxy rather than around it.
        static let dnsServers = ["1.1.1.1", "1.0.0.1"]
        static let taskStackSize = 20480
        static let tcpBufferSize = 4096
        static let connectTimeout = 5000
        static let readWriteTimeout = 60000
        // UDP through the tunnel is DNS, whose answer arrives in milliseconds,
        // and QUIC, which the engine blackholes so apps fall back to TCP. Held
        // for the full minute, those dead sessions were half of all sessions
        // during a speed test. Thirty seconds is the idle window NAT routers
        // already give UDP, so anything that keeps a flow alive sends sooner.
        static let udpReadWriteTimeout = 30000
        // iOS kills the extension at 50 MB. Measured on a device, each session
        // costs about 110 KB across tun2socks and the Go engine (goroutine
        // stacks, TLS and pipe buffers) over about 15 MB at rest, and closing
        // trails the cap by about a fifth, so 128 peaks near 32 MB. Past the
        // cap tun2socks closes the session idle the longest, not the new one:
        // a burst sheds stale keep-alives, never a transfer in progress.
        static let maxSessionCount = 128
        static let logLevel = "error"
        static let engineName = "xray"
        static let startMode = "simple"
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("⭐️ Starting tunnel provider...")
        #if DEBUG
        IosbridgeStartMemoryMonitorIOS(1000)
        #endif
        let config = getTunnelConfiguration(options: options)
        os_log("⭐️ Applying tunnel network settings...")
        let networkSettings = createNetworkSettings(
            mtu: config.mtu,
            ipv4Address: TunnelDefaults.tunnelIpv4,
            ipv6Address: TunnelDefaults.tunnelIpv6
        )


        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                os_log("❌ Failed to set network settings: %{public}@", error.localizedDescription)
                completionHandler(error)
                return
            }

            os_log("✅ Network settings applied successfully")

            // Off the queue the app's messages arrive on, as a quick launch
            // is, so a slow engine start does not hold them back.
            Self.launchQueue.async {
                if config.startMode == "normal"{
                    os_log("⭐️ Launching tunnel provider in normal mode")
                    let launched = self.launchTunnelProvider(
                        engineId: config.engineName,
                        workDir: config.cacheDir,
                        payload: config.engineConfig
                    )
                    // A tunnel with no engine behind it reads as connected and
                    // carries nothing; failing here lets the app say so.
                    guard launched else {
                        completionHandler(NSError(
                            domain: "BegzarEngineTunnel",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Engine did not start"]))
                        return
                    }
                }

                let tunnelConfig = self.createSocks5TunnelConfig(
                    mtu: config.mtu,
                    port: config.port,
                    address: config.address
                )

                self.startSocks5Tunnel(config: tunnelConfig)
                os_log("✅ Tunnel Started")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("⭐️ Shutting down tunnel provider...")
        IosbridgeShutdownEngineIOS()
        Tun2SocksKit.Socks5Tunnel.quit()
        #if DEBUG
        IosbridgeStopMemoryMonitorIOS()
        #endif
        os_log("✅ Tunnel deactivated")
        completionHandler()
    }
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
            guard let json = try? JSONSerialization.jsonObject(with: messageData, options: []),
                  let dict = json as? [String: String],
                  let command = dict["command"] else {
                os_log("❌ Invalid JSON or missing command.")
                completionHandler?(nil)
                return
            }

            os_log("⭐️ Received command: %{public}@", command)

            switch command {

            case "QUICK_LAUNCH_PROVIDER":
                os_log("⭐️ Launching tunnel provider in quick launch mode")
                let engineId = dict["engineName"]
                let payload = dict["config"]
                let workDir = dict["cacheDir"]
                // Messages from the app arrive one at a time, and a launch
                // takes seconds (WARP registers, handshakes and tests the
                // tunnel). Run here, it held back every message behind it, so
                // the log viewer saw nothing until the launch was over. Off
                // this queue, the viewer's reads are answered while it runs.
                Self.launchQueue.async {
                    let launched = self.launchTunnelProvider(
                        engineId: engineId, workDir: workDir, payload: payload)
                    // Why it failed is in the engine log, redacted; the reply
                    // only says whether the engine is serving.
                    let response = launched ? "true" : "false"
                    completionHandler?(response.data(using: .utf8))
                }
            case "QUICK_SHUTDOWN_PROVIDER":
                os_log("Shutting down provider from handle message")
                // Behind any launch still under way, on the same queue, so a
                // shutdown never lands before the launch it should undo. That
                // launch is cancelled first, here rather than on the queue: a
                // WARP or Psiphon start can take a minute, and it would
                // otherwise come up after the user asked to stop.
                IosbridgeCancelLaunchIOS()
                Self.launchQueue.async {
                    IosbridgeShutdownEngineIOS()
                    completionHandler?("true".data(using: .utf8))
                }

            case "IS_PROVIDER_ACTIVE":
                let isActive = IosbridgeIsEngineActiveIOS()
                let response = String(isActive)
                completionHandler?(response.data(using: .utf8))

            case "MEASURE_LATENCY":
                let targets = dict["urls"]
                let latencyResult = IosbridgeMeasureLatencyIOS(targets)
                if let responseData = latencyResult.data(using: String.Encoding.utf8) {
                    completionHandler?(responseData)
                } else {
                    completionHandler?(nil)
                }
            case "RETRIEVE_LOGS":
                let retrievedLogs = IosbridgeRetrieveLogsIOS()
                completionHandler?(retrievedLogs.data(using: .utf8))
            case "PURGE_LOGS":
                IosbridgePurgeLogsIOS()
                completionHandler?(nil)
            case "READ_ENGINE_LOG":
                // A serialized ReadEngineLogReply, base64 so it survives the
                // plugin's string reply. Every line in it is already redacted.
                // With a wait, the engine holds the read until a line arrives,
                // so it runs off this queue: the messages behind it, a launch
                // or a shutdown among them, are not held up.
                let after = Int64(dict["after"] ?? "") ?? 0
                let limit = Int32(dict["limit"] ?? "") ?? 0
                let wait = Int32(dict["wait"] ?? "") ?? 0
                DispatchQueue.global(qos: .utility).async {
                    var error: NSError?
                    let reply = IosbridgeReadEngineLogIOS(after, limit, wait, &error)
                    if error != nil {
                        completionHandler?(nil)
                    } else {
                        completionHandler?(reply?.base64EncodedString().data(using: .utf8))
                    }
                }
            case "CLEAR_ENGINE_LOG":
                IosbridgeClearEngineLogIOS()
                completionHandler?(nil)
            case "GET_REVISION":
                let revision = IosbridgeGetRevisionIOS()
                completionHandler?(revision.data(using: .utf8))
                
            case "GET_MEMORY_FOOTPRINT":
                let footprint = IosbridgeMemoryFootprintIOS()
                completionHandler?(footprint.data(using: .utf8))
                
            case "GET_PROCESSOR_LOAD":
                let load = IosbridgeProcessorLoadIOS()
                completionHandler?(load.data(using: .utf8))
            

            default:
                os_log("❌ Unknown command received: %{public}@", command)
                completionHandler?(nil)
            }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        os_log("⭐️ Tunnel going to sleep...")
        completionHandler()
    }

    override func wake() {
        os_log("⭐️ Tunnel waking up...")
    }

    private struct TunnelConfiguration {
        let port: Int32
        let address: String
        let mtu: Int
        let engineConfig: String?
        let cacheDir: String?
        let engineName: String?
        let startMode: String?
    }

    private func getTunnelConfiguration(options: [String: NSObject]?) -> TunnelConfiguration {
        var port: Int32 = TunnelDefaults.port
        var address: String = TunnelDefaults.address
        var mtu: Int = TunnelDefaults.mtu
        var engineName: String = TunnelDefaults.engineName
        var tunnelMode: String = TunnelDefaults.startMode
        if let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
           let configData = providerConfig["config"] as? Data,
           let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {

            if let startMode = config["startMode"] as? String {
                tunnelMode = startMode
            }
            if let configPort = config["port"] as? Int {
                port = Int32(configPort)
            }

            if let configAddress = config["address"] as? String {
                address = configAddress
            }

            if let configMtu = config["mtu"] as? Int {
                mtu = configMtu
            }
        }

        if let optPort = (options?["port"] as? NSNumber)?.int32Value {
            port = optPort
        }

        if let optAddress = options?["address"] as? String {
            address = optAddress
        }

        if let optMtu = (options?["mtu"] as? NSNumber)?.intValue {
            mtu = optMtu
        }

        if let optEngineName = options?["engineName"] as? String {
            engineName = optEngineName
        }

        if let optStartMode = options?["startMode"] as? String {
            tunnelMode = optStartMode
        }

        let engineConfig = options?["config"] as? String
        let cacheDir = options?["cacheDir"] as? String

        return TunnelConfiguration(
            port: port,
            address: address,
            mtu: mtu,
            engineConfig: engineConfig,
            cacheDir: cacheDir,
            engineName: engineName,
            startMode: tunnelMode
        )
    }

    private func createNetworkSettings(mtu: Int, ipv4Address: String, ipv6Address: String) -> NEPacketTunnelNetworkSettings {
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: TunnelDefaults.tunnelAddress)
        networkSettings.mtu = NSNumber(value: mtu)

        let ipv4Settings = NEIPv4Settings(addresses: [ipv4Address], subnetMasks: [TunnelDefaults.tunnelIpv4Mask])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4Settings

        let ipv6Settings = NEIPv6Settings(addresses: [ipv6Address], networkPrefixLengths: [NSNumber(value: TunnelDefaults.tunnelIpv6PrefixLength)])
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        networkSettings.ipv6Settings = ipv6Settings

        networkSettings.dnsSettings = NEDNSSettings(servers: TunnelDefaults.dnsServers)

        return networkSettings
    }

    private func createSocks5TunnelConfig(mtu: Int, port: Int32, address: String) -> String {
        return """
        tunnel:
            mtu: \(mtu)
            ipv4: \(TunnelDefaults.tunnelIpv4)
            ipv6: '\(TunnelDefaults.tunnelIpv6)'

        socks5:
            port: \(port)
            address: \(address)
            udp: 'udp'
            pipeline: true

        misc:
            task-stack-size: \(TunnelDefaults.taskStackSize)
            tcp-buffer-size: \(TunnelDefaults.tcpBufferSize)
            connect-timeout: \(TunnelDefaults.connectTimeout)
            read-write-timeout: \(TunnelDefaults.readWriteTimeout)
            udp-read-write-timeout: \(TunnelDefaults.udpReadWriteTimeout)
            max-session-count: \(TunnelDefaults.maxSessionCount)
            log-file: stderr
            log-level: \(TunnelDefaults.logLevel)
        """
    }

    /// Whether the engine is serving on the SOCKS port tun2socks forwards to.
    private func launchTunnelProvider(engineId: String?, workDir: String?, payload: String?) -> Bool {
        guard let workDir = workDir, let payload = payload else {
            os_log("❌ Missing work directory or payload configuration")
            return false
        }

        let dir = engineWorkDir(requested: workDir)
        let launchOutcome = IosbridgeLaunchEngineIOS(engineId, dir, payload, 128, true, 2080)

        if launchOutcome == "true" {
            os_log("✅ Provider launched successfully")
            return true
        }
        // The engine's error can name the server; it is kept, redacted, in
        // the engine log rather than printed here.
        os_log("❌ Provider launch failed: %{private}@", launchOutcome)
        return false
    }

    /// The app sends its Documents path, which is in the app's own container:
    /// this extension may neither read nor write it. WARP saves its device
    /// identity there and stopped at the first launch, so every engine works
    /// in the app group's container instead, as on macOS.
    private func engineWorkDir(requested: String) -> String {
        guard let group = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupId)
        else {
            return requested
        }
        let dir = group.appendingPathComponent("begzar", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            os_log("❌ Could not create the engine directory")
            return requested
        }
        return dir.path
    }

    private func startSocks5Tunnel(config: String) {
        Socks5Tunnel.run(withConfig: .string(content: config)) { result in
            os_log("⭐️ Tunnel exit code: %d", result)
        }
    }
}
