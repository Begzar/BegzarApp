package cloud.begzar.begzar.security

object BegzarSecurityNative {
    init {
        System.loadLibrary("begzar_security")
    }

    external fun performSecurityChecksNative(certSha256: String): Int
}
