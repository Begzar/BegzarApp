#include "anti_instrumentation.h"
#include "integrity.h"

#include <jni.h>
#include <stdio.h>
#include <string.h>

static jint perform_security_checks(JNIEnv *env, jstring cert_sha256) {
    int flags = 0;
    if (begzar_detect_debugger()) {
        flags |= BEGZAR_THREAT_DEBUGGER;
    }
    if (begzar_detect_instrumentation()) {
        flags |= BEGZAR_THREAT_INSTRUMENTATION;
    }
    if (begzar_detect_emulator()) {
        flags |= BEGZAR_THREAT_EMULATOR;
    }

    const char *cert = env->GetStringUTFChars(cert_sha256, nullptr);
    if (cert == nullptr || !begzar_verify_signature(cert)) {
        flags |= BEGZAR_THREAT_TAMPERED;
    }
    if (cert != nullptr) {
        env->ReleaseStringUTFChars(cert_sha256, cert);
    }
    return flags;
}

extern "C" JNIEXPORT jint JNICALL
Java_cloud_begzar_begzar_security_BegzarSecurityNative_performSecurityChecksNative(
    JNIEnv *env, jclass, jstring cert_sha256) {
    return perform_security_checks(env, cert_sha256);
}
