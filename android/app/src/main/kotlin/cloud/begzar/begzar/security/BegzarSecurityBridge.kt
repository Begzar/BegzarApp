package cloud.begzar.begzar.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import cloud.begzar.begzar.BuildConfig
import java.security.MessageDigest

object BegzarSecurityBridge {
    const val THREAT_DEBUGGER = 1
    const val THREAT_INSTRUMENTATION = 2
    const val THREAT_TAMPERED = 4
    const val THREAT_EMULATOR = 8

    fun signingCertificateSha256(context: Context): String {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNATURES,
            )
        }

        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            packageInfo.signatures
        } ?: return ""

        if (signatures.isEmpty()) return ""

        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(signatures[0].toByteArray())
        return hash.joinToString("") { byte -> "%02x".format(byte) }
    }

    fun performSecurityChecks(context: Context): Int {
        val cert = signingCertificateSha256(context)
        var flags = BegzarSecurityNative.performSecurityChecksNative(cert)
        if (BuildConfig.DEBUG) {
            flags = flags and THREAT_TAMPERED.inv()
            flags = flags and THREAT_EMULATOR.inv()
        } else if (isGooglePlayInstall(context)) {
            // Play App Signing re-signs with Google's cert, not the upload key.
            flags = flags and THREAT_TAMPERED.inv()
        }
        return flags
    }

    private fun isGooglePlayInstall(context: Context): Boolean {
        val playPackages = setOf(
            "com.android.vending",
            "com.google.android.feedback",
        )
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val info = context.packageManager.getInstallSourceInfo(context.packageName)
                info.installingPackageName in playPackages ||
                    info.initiatingPackageName in playPackages
            } else {
                @Suppress("DEPRECATION")
                val installer =
                    context.packageManager.getInstallerPackageName(context.packageName)
                installer in playPackages
            }
        } catch (_: Exception) {
            false
        }
    }
}
