package cloud.begzar.begzar

import android.app.UiModeManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telephony.TelephonyManager
import cloud.begzar.begzar.security.BegzarSecurityChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val urlChannelName = "cloud.begzar.begzar/url_launcher"
    private val deviceInfoChannelName = "cloud.begzar.begzar/device_info"
    private val otherVpnChannelName = "cloud.begzar.begzar/other_vpn"
    private val launchAppearanceChannelName = "cloud.begzar.begzar/launch_appearance"

    // Android 12 and up fades its splash out and then fades the app in, which
    // dims the dial in between. The app's first frames draw the same dial in
    // the same place (lib/app/launch_cover.dart), so the splash is removed at
    // once instead: a cut between two identical pictures.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splash -> splash.remove() }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BegzarSecurityChannel.CHANNEL)
            .setMethodCallHandler(BegzarSecurityChannel(this))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, urlChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.arguments as? String
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_URL", "URL is empty", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceInfoChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceName" -> result.success(buildDeviceName())
                    "getRegionSignals" -> result.success(readRegionSignals())
                    else -> result.notImplemented()
                }
            }

        // Turning another app's VPN off is not here: the plugin's prepare does
        // it, because making Begzar the VPN app is what takes the other down.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, otherVpnChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isVpnOn" -> result.success(isVpnOn())
                    "openVpnSettings" -> result.success(openVpnSettings())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, launchAppearanceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "follow" -> {
                        followThemeOnLaunch(call.arguments as? String)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // The launch window is drawn before Dart runs, from the values or
    // values-night resources. Android 12 and up keeps an app's own night mode
    // across launches and draws the next splash in it, so the theme picked in
    // Settings reaches the launch window too. Older versions have no such
    // setting and follow the phone. The manifest handles uiMode itself, so
    // changing it here does not recreate the activity.
    private fun followThemeOnLaunch(themeMode: String?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val uiMode = getSystemService(UiModeManager::class.java) ?: return
        uiMode.setApplicationNightMode(
            when (themeMode) {
                "light" -> UiModeManager.MODE_NIGHT_NO
                "dark" -> UiModeManager.MODE_NIGHT_YES
                else -> UiModeManager.MODE_NIGHT_AUTO
            }
        )
    }

    // Whether this app's traffic leaves through a VPN right now. Any app's VPN
    // counts, Begzar's own included; Dart rules Begzar's out before it asks.
    // A VPN that excludes Begzar does not count, and needs no turning off:
    // nothing Begzar measures goes through it.
    private fun isVpnOn(): Boolean {
        val connectivity = getSystemService(ConnectivityManager::class.java) ?: return false
        val capabilities =
            connectivity.getNetworkCapabilities(connectivity.activeNetwork) ?: return false
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
    }

    private fun openVpnSettings(): Boolean {
        return try {
            startActivity(Intent(Settings.ACTION_VPN_SETTINGS))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    // Where the device says it is, for routing a purchase. None of these asks
    // for a permission. A device with no telephony, or no SIM, answers null or
    // an empty string for the two countries, which Dart reads as silence.
    private fun readRegionSignals(): Map<String, String?> {
        val telephony = try {
            getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        } catch (e: Exception) {
            null
        }
        return mapOf(
            "timeZoneId" to TimeZone.getDefault().id,
            "simCountry" to try { telephony?.simCountryIso } catch (e: Exception) { null },
            "networkCountry" to try { telephony?.networkCountryIso } catch (e: Exception) { null },
        )
    }

    private fun buildDeviceName(): String {
        val brand = Build.BRAND?.trim().orEmpty()
        val model = Build.MODEL?.trim().orEmpty()

        if (brand.isNotEmpty() && model.isNotEmpty()) {
            val brandTitle = brand.replaceFirstChar { char ->
                if (char.isLowerCase()) char.titlecase() else char.toString()
            }
            return if (model.contains(brand, ignoreCase = true)) {
                model
            } else {
                "$brandTitle $model"
            }
        }

        return model.ifEmpty { "Android Device" }
    }
}
