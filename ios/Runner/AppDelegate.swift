import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // The interface names iOS gives what a VPN runs over. No API names another
  // app's tunnel, so a scoped proxy entry under one of these is how a running
  // VPN shows itself to an app that does not own it. Begzar's own shows up
  // the same way; Dart rules it out before it asks.
  private static let vpnInterfacePrefixes = ["utun", "ipsec", "ppp", "tap", "tun"]

  private static func isVpnOn() -> Bool {
    guard
      let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue()
        as? [String: Any],
      let scoped = settings["__SCOPED__"] as? [String: Any]
    else { return false }
    return scoped.keys.contains { name in
      vpnInterfacePrefixes.contains { name.hasPrefix($0) }
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Under the scene lifecycle the window belongs to the scene and does not
  // exist yet at launch, so plugins and channels attach to the engine here,
  // once the storyboard's FlutterViewController has created it.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    let channel = FlutterMethodChannel(
      name: "cloud.begzar.begzar/device_info",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getDeviceName":
        let device = UIDevice.current
        let name = device.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result(name.isEmpty ? device.model : name)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Turning another app's VPN off is the plugin's takeOverVpn, which saves
    // Begzar's configuration enabled. iOS has no public link to its VPN page,
    // so the settings button opens Begzar's own page, one level below it.
    let otherVpnChannel = FlutterMethodChannel(
      name: "cloud.begzar.begzar/other_vpn",
      binaryMessenger: messenger
    )
    otherVpnChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "isVpnOn":
        result(AppDelegate.isVpnOn())
      case "openVpnSettings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url) { opened in
          result(opened)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // BegzarEngineKit lives on Runner, not the begzar_engine pod — real-delay probes
    // run here so the server picker never opens the packet tunnel, and so
    // does the config build, which the tunnel is then handed.
    let realDelayChannel = FlutterMethodChannel(
      name: "begzar_engine/real_delay",
      binaryMessenger: messenger
    )
    realDelayChannel.setMethodCallHandler { call, result in
      // The engine log of this process: what its in-app probes and config
      // builds said. The tunnel's own is read through the tunnel.
      if call.method == "readEngineLog" {
        let args = call.arguments as? [String: Any]
        let after = args?["after"] as? Int ?? 0
        let limit = args?["limit"] as? Int ?? 0
        switch BegzarDirectProbe.readEngineLog(after: after, limit: limit) {
        case .success(let reply):
          result(FlutterStandardTypedData(bytes: reply))
        case .failure(let error):
          result(
            FlutterError(
              code: "READ_LOG_FAILED",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
        return
      }
      if call.method == "clearEngineLog" {
        BegzarDirectProbe.clearEngineLog()
        result(nil)
        return
      }
      if call.method == "buildEngineConfig" {
        guard let request = call.arguments as? FlutterStandardTypedData else {
          result(
            FlutterError(
              code: "INVALID_ARGUMENT",
              message: "Missing request for buildEngineConfig",
              details: nil
            )
          )
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let built = BegzarDirectProbe.buildEngineConfig(request: request.data)
          DispatchQueue.main.async {
            switch built {
            case .success(let config):
              result(config)
            case .failure(let error):
              result(
                FlutterError(
                  code: "BUILD_FAILED",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          }
        }
        return
      }
      // The app's backend operations, which the engine runs. They reach the
      // network, so they run off the main thread.
      if call.method == "backendCall" {
        guard let request = call.arguments as? FlutterStandardTypedData else {
          result(
            FlutterError(
              code: "INVALID_ARGUMENT",
              message: "Missing request for \(call.method)",
              details: nil
            )
          )
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let reply = BegzarDirectProbe.backendCall(call: request.data)
          DispatchQueue.main.async {
            switch reply {
            case .success(let bytes):
              result(FlutterStandardTypedData(bytes: bytes))
            case .failure(let error):
              result(
                FlutterError(
                  code: "API_FAILED",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          }
        }
        return
      }
      guard call.method == "realDelayAll" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let links = args["links"] as? String
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Missing links for realDelayAll",
            details: nil
          )
        )
        return
      }
      let endpoint = args["endpoint"] as? String
      let stopAfter = args["stopAfter"] as? Int ?? 0
      DispatchQueue.global(qos: .userInitiated).async {
        let latency = BegzarDirectProbe.realDelayAll(
          links: links,
          endpoint: endpoint,
          stopAfter: stopAfter
        )
        DispatchQueue.main.async {
          result(latency)
        }
      }
    }
  }
}
