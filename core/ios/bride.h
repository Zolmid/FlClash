#pragma once

#include <stdlib.h>
#include <stdint.h>

extern void (*release_object_func)(void *obj);
extern void *(*retain_object_func)(void *obj);
extern void (*free_string_func)(char *data);
extern int (*protect_func)(void *tun_interface, int fd);
extern int (*resolve_uid_func)(void *tun_interface, int protocol, const char *source, const char *target);
extern char *(*resolve_package_func)(void *tun_interface, int uid);
extern void (*result_func)(void *invoke_interface, const char *data);
extern void (*system_log_func)(const char *level, const char *message);

extern void release_object(void *obj);
extern void *retain_object(void *obj);
extern void free_string(char *data);
extern void result(void *invoke_interface, const char *data);
extern void system_log(const char *level, const char *message);
extern uint64_t flclash_physical_footprint(void);
