#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Compare APK signing certificate SHA-256 (hex lowercase, no colons) passed from Java.
int begzar_verify_signature(const char *cert_sha256_hex);

#ifdef __cplusplus
}
#endif
