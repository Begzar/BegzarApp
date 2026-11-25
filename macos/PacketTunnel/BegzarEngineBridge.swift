import Foundation

/// Thin Swift wrapper over the cgo exports in `libbegzar_engine.xcframework`.
enum BegzarEngineBridge {
    @discardableResult
    static func bootGateway() -> Bool {
        BegzarBootGateway() != 0
    }

    static func launch(
        engineId: String?,
        workDir: String,
        payload: String,
        memLimit: Int32 = 128,
        isRawPayload: Bool = true,
        socksPort: Int32 = 2080
    ) -> String {
        let engine = strdup(engineId ?? "xray")
        let work = strdup(workDir)
        let body = strdup(payload)
        defer {
            free(engine)
            free(work)
            free(body)
        }
        guard let result = BegzarLaunchEngine(
            engine, work, body, memLimit, isRawPayload, socksPort
        ) else {
            return "ERROR_ENGINE: null result"
        }
        defer { BegzarFreeCString(result) }
        return String(cString: result)
    }

    @discardableResult
    static func shutdown() -> Bool {
        BegzarShutdownEngine() != 0
    }

    static func isActive() -> Bool {
        BegzarIsEngineActive() != 0
    }

    static func measureLatency(targets: String?) -> String {
        let targetsC = strdup(targets ?? "")
        defer { free(targetsC) }
        guard let result = BegzarMeasureLatency(targetsC) else { return "" }
        defer { BegzarFreeCString(result) }
        return String(cString: result)
    }

    static func retrieveLogs() -> String {
        guard let result = BegzarRetrieveLogs() else { return "" }
        defer { BegzarFreeCString(result) }
        return String(cString: result)
    }

    static func purgeLogs() {
        BegzarPurgeLogs()
    }

    static func revision() -> String {
        guard let result = BegzarGetRevision() else { return "unknown" }
        defer { BegzarFreeCString(result) }
        return String(cString: result)
    }

    static func memoryFootprint() -> String {
        guard let result = BegzarMemoryFootprint() else { return "0" }
        defer { BegzarFreeCString(result) }
        return String(cString: result)
    }

    static func processorLoad() -> String {
        guard let result = BegzarProcessorLoad() else { return "0" }
        defer { BegzarFreeCString(result) }
        return String(cString: result)
    }
}

