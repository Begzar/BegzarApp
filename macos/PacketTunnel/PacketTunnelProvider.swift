import NetworkExtension
import Tun2SocksKit

/// macOS Packet Tunnel: Tun2SocksKit → local SOCKS; engine via `libbegzar_engine`
class PacketTunnelProvider: NEPacketTunnelProvider {
    private static let appGroupId = "group.cloud.begzar.begzarvpnG"

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
        static let logLevel = "error"
        static let engineName = "xray"
        static let startMode = "simple"
    }

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // Best-effort; never block tunnel bring-up on gateway boot.
        _ = BegzarEngineBridge.bootGateway()

        let config = getTunnelConfiguration(options: options)
        let networkSettings = createNetworkSettings(
            mtu: config.mtu,
            ipv4Address: TunnelDefaults.tunnelIpv4,
            ipv6Address: TunnelDefaults.tunnelIpv6
        )

        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completionHandler(error)
                return
            }

            if config.startMode == "normal" {
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

            completionHandler(nil)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        _ = BegzarEngineBridge.shutdown()
        Tun2SocksKit.Socks5Tunnel.quit()
        completionHandler()
    }

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)?
    ) {
        guard let json = try? JSONSerialization.jsonObject(with: messageData),
              let dict = json as? [String: String],
              let command = dict["command"]
        else {
            completionHandler?(nil)
            return
        }


        switch command {
        case "QUICK_LAUNCH_PROVIDER":
            let launched = launchTunnelProvider(
                engineId: dict["engineName"],
                workDir: dict["cacheDir"],
                payload: dict["config"]
            )
            // Why it failed is in the engine log, redacted; the reply only
            // says whether the engine is serving.
            completionHandler?((launched ? "true" : "false").data(using: .utf8))

        case "QUICK_SHUTDOWN_PROVIDER":
            _ = BegzarEngineBridge.shutdown()
            completionHandler?("true".data(using: .utf8))

        case "IS_PROVIDER_ACTIVE":
            completionHandler?(String(BegzarEngineBridge.isActive()).data(using: .utf8))

        case "MEASURE_LATENCY":
            let latencyResult = BegzarEngineBridge.measureLatency(targets: dict["urls"])
            completionHandler?(latencyResult.data(using: .utf8))

        case "RETRIEVE_LOGS":
            completionHandler?(BegzarEngineBridge.retrieveLogs().data(using: .utf8))

        case "PURGE_LOGS":
            BegzarEngineBridge.purgeLogs()
            completionHandler?(nil)

        case "GET_REVISION":
            completionHandler?(BegzarEngineBridge.revision().data(using: .utf8))

        case "GET_MEMORY_FOOTPRINT":
            completionHandler?(BegzarEngineBridge.memoryFootprint().data(using: .utf8))

        case "GET_PROCESSOR_LOAD":
            completionHandler?(BegzarEngineBridge.processorLoad().data(using: .utf8))

        default:
            completionHandler?(nil)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {}

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

        if let providerConfig =
            (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
           let configData = providerConfig["config"] as? Data,
           let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any]
        {
            if let startMode = config["startMode"] as? String { tunnelMode = startMode }
            if let configPort = config["port"] as? Int { port = Int32(configPort) }
            if let configAddress = config["address"] as? String { address = configAddress }
            if let configMtu = config["mtu"] as? Int { mtu = configMtu }
        }

        if let optPort = (options?["port"] as? NSNumber)?.int32Value { port = optPort }
        if let optAddress = options?["address"] as? String { address = optAddress }
        if let optMtu = (options?["mtu"] as? NSNumber)?.intValue { mtu = optMtu }
        if let optEngineName = options?["engineName"] as? String { engineName = optEngineName }
        if let optStartMode = options?["startMode"] as? String { tunnelMode = optStartMode }

        return TunnelConfiguration(
            port: port,
            address: address,
            mtu: mtu,
            engineConfig: options?["config"] as? String,
            cacheDir: options?["cacheDir"] as? String,
            engineName: engineName,
            startMode: tunnelMode
        )
    }

    private func createNetworkSettings(
        mtu: Int,
        ipv4Address: String,
        ipv6Address: String
    ) -> NEPacketTunnelNetworkSettings {
        let networkSettings = NEPacketTunnelNetworkSettings(
            tunnelRemoteAddress: TunnelDefaults.tunnelAddress
        )
        networkSettings.mtu = NSNumber(value: mtu)

        let ipv4Settings = NEIPv4Settings(
            addresses: [ipv4Address],
            subnetMasks: [TunnelDefaults.tunnelIpv4Mask]
        )
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4Settings

        let ipv6Settings = NEIPv6Settings(
            addresses: [ipv6Address],
            networkPrefixLengths: [NSNumber(value: TunnelDefaults.tunnelIpv6PrefixLength)]
        )
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        networkSettings.ipv6Settings = ipv6Settings

        networkSettings.dnsSettings = NEDNSSettings(servers: TunnelDefaults.dnsServers)
        return networkSettings
    }

    private func createSocks5TunnelConfig(mtu: Int, port: Int32, address: String) -> String {
        """
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
            log-file: /dev/null
            log-level: \(TunnelDefaults.logLevel)
        """
    }

    /// Whether the engine is serving on the SOCKS port tun2socks forwards to.
    private func launchTunnelProvider(engineId: String?, workDir: String?, payload: String?) -> Bool {
        guard let payload else {
            return false
        }

        let resolvedDir = resolveWorkDirectory(workDir)
        let outcome = BegzarEngineBridge.launch(
            engineId: engineId,
            workDir: resolvedDir,
            payload: payload
        )
        return outcome == "true"
    }

    /// Host Documents are not readable from the appex sandbox; prefer App Group.
    private func resolveWorkDirectory(_ preferred: String?) -> String {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupId
        ) {
            let dir = groupURL.appendingPathComponent("begzar", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.path
        }
        if let preferred, !preferred.isEmpty {
            return preferred
        }
        return FileManager.default.temporaryDirectory.path
    }

    private func startSocks5Tunnel(config: String) {
        Socks5Tunnel.run(withConfig: .string(content: config)) { result in
        }
    }
}
