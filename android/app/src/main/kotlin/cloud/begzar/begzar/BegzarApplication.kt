package cloud.begzar.begzar

import android.app.Application

/// Loads the native security gate before anything else runs. The proxy
/// engine's own native setup (relaxing fdsan for the tunnel's descriptor)
/// belongs to the engine's plugin and its VPN service, not to the app.
class BegzarApplication : Application() {
    companion object {
        init {
            try {
                System.loadLibrary("begzar_security")
            } catch (_: UnsatisfiedLinkError) {
            }
        }
    }
}
