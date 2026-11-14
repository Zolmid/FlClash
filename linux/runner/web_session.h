#ifndef RUNNER_WEB_SESSION_H_
#define RUNNER_WEB_SESSION_H_

#include <flutter_linux/flutter_linux.h>

void register_web_session(FlBinaryMessenger* messenger);
void close_web_session();

#endif
