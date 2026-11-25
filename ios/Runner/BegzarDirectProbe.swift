import Foundation
import BegzarEngineKit

/// In-process real-delay probes in the Runner app (no packet tunnel).
enum BegzarDirectProbe {
    private static let defaultEndpoint = "https://www.google.com/generate_204"

    /// `stopAfter` above 0 returns once that many links have answered; 0 probes
    /// every link.
    static func realDelayAll(links: String, endpoint: String?, stopAfter: Int) -> String {
        let probe = (endpoint?.isEmpty == false) ? endpoint! : defaultEndpoint
        return IosbridgeRealDelayAllIOS(links, probe, Int32(clamping: stopAfter))
    }

    /// This process's engine log after `after`, as a serialized
    /// `ReadEngineLogReply`. Every line in it is already redacted.
    static func readEngineLog(after: Int, limit: Int) -> Result<Data, Error> {
        var error: NSError?
        let reply = IosbridgeReadEngineLogIOS(Int64(after), Int32(clamping: limit), 0, &error)
        if let error = error {
            return .failure(error)
        }
        return .success(reply ?? Data())
    }

    static func clearEngineLog() {
        IosbridgeClearEngineLogIOS()
    }

    /// The complete engine config for a serialized `BuildEngineConfigRequest`:
    /// its share link parsed by the real-delay parser, with the app's settings
    /// written around it.
    static func buildEngineConfig(request: Data) -> Result<String, Error> {
        var error: NSError?
        let config = IosbridgeBuildEngineConfigIOS(request, &error)
        if let error = error {
            return .failure(error)
        }
        return .success(config)
    }

    /// One of the app's backend operations: a serialized BackendCall in, a
    /// serialized BackendReply out.
    static func backendCall(call: Data) -> Result<Data, Error> {
        var error: NSError?
        let reply = IosbridgeBackendCallIOS(call, &error)
        if let error = error {
            return .failure(error)
        }
        return .success(reply ?? Data())
    }
}
