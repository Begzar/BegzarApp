#include "integrity.h"

#include <ctype.h>
#include <string.h>

// Upload key certificate SHA-256 (local release / sideload).
// Regenerate: openssl x509 -in upload_certificate.pem -noout -fingerprint -sha256
static const char kUploadCertSha256[] =
    "c11b5d7bac4365a25ae1bc98ef8c0ba04e1e1b84fe84ef58ba305358a33cc34d";

// Google Play App Signing certificate (APK delivered to users).
// Set via Gradle: -DPLAY_APP_SIGNING_CERT_SHA256=... (Play Console → App signing).
#ifdef PLAY_APP_SIGNING_CERT_SHA256
static const char kPlayAppSigningCertSha256[] = PLAY_APP_SIGNING_CERT_SHA256;
#endif

static int hex_eq(const char *a, const char *b) {
    if (!a || !b) {
        return 0;
    }
    while (*a && *b) {
        if (tolower((unsigned char)*a) != tolower((unsigned char)*b)) {
            return 0;
        }
        ++a;
        ++b;
    }
    return *a == '\0' && *b == '\0';
}

static int matches_allowed_signing_cert(const char *cert_sha256_hex) {
    if (cert_sha256_hex == NULL || cert_sha256_hex[0] == '\0') {
        return 0;
    }
    if (hex_eq(cert_sha256_hex, kUploadCertSha256)) {
        return 1;
    }
#ifdef PLAY_APP_SIGNING_CERT_SHA256
    if (hex_eq(cert_sha256_hex, kPlayAppSigningCertSha256)) {
        return 1;
    }
#endif
    return 0;
}

int begzar_verify_signature(const char *cert_sha256_hex) {
    return matches_allowed_signing_cert(cert_sha256_hex);
}
