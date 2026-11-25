#include "anti_instrumentation.h"

#include <ctype.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/system_properties.h>
#include <unistd.h>

static int read_tracer_pid() {
    FILE *f = fopen("/proc/self/status", "r");
    if (!f) {
        return 0;
    }
    char line[256];
    int tracer = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "TracerPid:", 10) == 0) {
            tracer = atoi(line + 10);
            break;
        }
    }
    fclose(f);
    return tracer;
}

static int maps_contains(const char *needle) {
    FILE *f = fopen("/proc/self/maps", "r");
    if (!f) {
        return 0;
    }
    char line[512];
    int found = 0;
    while (fgets(line, sizeof(line), f)) {
        for (char *p = line; *p; ++p) {
            *p = (char)tolower((unsigned char)*p);
        }
        if (strstr(line, needle) != NULL) {
            found = 1;
            break;
        }
    }
    fclose(f);
    return found;
}

int begzar_detect_debugger() {
    return read_tracer_pid() != 0 ? 1 : 0;
}

int begzar_detect_instrumentation() {
    static const char *needles[] = {
        "frida",       "gum-js",     "xposed",     "lsposed",
        "substrate",   "magisk",     "riru",       "libgadget",
        "libfrida",    "linjector",  "zygisk",     "edxposed",
    };
    for (size_t i = 0; i < sizeof(needles) / sizeof(needles[0]); ++i) {
        if (maps_contains(needles[i])) {
            return 1;
        }
    }

    // Suspicious server ports commonly used by Frida.
    static const char *ports[] = {"27042", "27043"};
    for (size_t i = 0; i < sizeof(ports) / sizeof(ports[0]); ++i) {
        char path[64];
        snprintf(path, sizeof(path), "/proc/net/tcp");
        FILE *f = fopen(path, "r");
        if (!f) {
            continue;
        }
        char line[256];
        while (fgets(line, sizeof(line), f)) {
            if (strstr(line, ports[i]) != NULL) {
                fclose(f);
                return 1;
            }
        }
        fclose(f);
    }
    return 0;
}

int begzar_detect_emulator() {
    static const char *paths[] = {
        "/dev/qemu_pipe",
        "/dev/socket/qemud",
        "/system/lib/libc_malloc_debug_qemu.so",
        "/sys/qemu_trace",
        "/system/bin/qemu-props",
    };
    for (size_t i = 0; i < sizeof(paths) / sizeof(paths[0]); ++i) {
        if (access(paths[i], F_OK) == 0) {
            return 1;
        }
    }

    char prop[92];
    __system_property_get("ro.hardware", prop);
    if (strstr(prop, "goldfish") || strstr(prop, "ranchu") ||
        strstr(prop, "vbox")) {
        return 1;
    }
    __system_property_get("ro.product.model", prop);
    if (strstr(prop, "sdk") || strstr(prop, "Emulator")) {
        return 1;
    }
    return 0;
}
