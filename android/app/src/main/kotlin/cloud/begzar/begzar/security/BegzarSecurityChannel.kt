package cloud.begzar.begzar.security

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BegzarSecurityChannel(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "cloud.begzar.begzar/security"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "performSecurityChecks" -> {
                    val flags = BegzarSecurityBridge.performSecurityChecks(context)
                    result.success(flags)
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("SECURITY_ERROR", e.message, null)
        }
    }
}
