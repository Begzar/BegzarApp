#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Bit flags returned by security checks.
#define BEGZAR_THREAT_DEBUGGER 1
#define BEGZAR_THREAT_INSTRUMENTATION 2
#define BEGZAR_THREAT_TAMPERED 4
#define BEGZAR_THREAT_EMULATOR 8

int begzar_detect_debugger();
int begzar_detect_instrumentation();
int begzar_detect_emulator();

#ifdef __cplusplus
}
#endif
