//go:build ios && cgo

#include "bride.h"

void (*release_object_func)(void *obj);
void *(*retain_object_func)(void *obj);
void (*free_string_func)(char *data);
int (*protect_func)(void *tun_interface, int fd);
int (*resolve_uid_func)(void *tun_interface, int protocol, const char *source, const char *target);
char *(*resolve_package_func)(void *tun_interface, int uid);
void (*result_func)(void *invoke_interface, const char *data);
void (*system_log_func)(const char *level, const char *message);

void release_object(void *obj) {
    if (obj != NULL && release_object_func != NULL) {
        release_object_func(obj);
    }
}

void *retain_object(void *obj) {
    return obj == NULL || retain_object_func == NULL ? NULL : retain_object_func(obj);
}

void free_string(char *data) {
    if (free_string_func == NULL) {
        free(data);
    } else {
        free_string_func(data);
    }
}

void result(void *invoke_interface, const char *data) {
    if (invoke_interface != NULL && result_func != NULL) {
        result_func(invoke_interface, data);
    }
}

void system_log(const char *level, const char *message) {
    if (system_log_func != NULL) {
        system_log_func(level, message);
    }
}
