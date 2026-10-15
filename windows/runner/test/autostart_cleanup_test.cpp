#include "autostart_cleanup.h"

#include <iostream>
#include <string>

namespace {

const autostart::Identity identity{
    L"S-1-5-21-123-456-789-1001", L"3f728a9b45b4e123",
    L"c:\\apps & tools\\flclash\\flclash.exe"};

autostart::Task OwnedTask() {
  return {identity.TaskName(), identity.Source(), identity.sid, identity.sid,
          identity.executable, L"", 1, 1, true, true, true, true};
}

bool Run(const std::string& name) {
  auto task = OwnedTask();
  if (name == "owned") return autostart::OwnsTask(identity, task);
  if (name == "other_user") {
    const autostart::Identity other{L"S-1-5-21-123-456-789-1002",
                                    identity.installation, identity.executable};
    if (autostart::OwnsTask(other, task)) return false;
    task.principal_sid = other.sid;
    if (autostart::OwnsTask(identity, task)) return false;
    task = OwnedTask();
    task.trigger_sid = other.sid;
    return !autostart::OwnsTask(identity, task);
  }
  if (name == "other_install") {
    const autostart::Identity other{identity.sid, L"f0123456789abcde",
                                    L"c:\\other\\flclash.exe"};
    return !autostart::OwnsTask(other, task);
  }
  if (name == "source") {
    task.source = L"other.application";
    if (autostart::OwnsTask(identity, task)) return false;
    task = OwnedTask();
    task.name += L"_other";
    return !autostart::OwnsTask(identity, task);
  }
  if (name == "command") {
    task.executable = L"c:\\other\\flclash.exe";
    return !autostart::OwnsTask(identity, task);
  }
  if (name == "shape") {
    task.action_count = 2;
    if (autostart::OwnsTask(identity, task)) return false;
    task = OwnedTask();
    task.trigger_count = 2;
    if (autostart::OwnsTask(identity, task)) return false;
    task = OwnedTask();
    task.exec_action = false;
    if (autostart::OwnsTask(identity, task)) return false;
    task = OwnedTask();
    task.logon_trigger = false;
    return !autostart::OwnsTask(identity, task);
  }
  if (name == "principal") {
    task.least_privilege = false;
    if (autostart::OwnsTask(identity, task)) return false;
    task = OwnedTask();
    task.interactive = false;
    return !autostart::OwnsTask(identity, task);
  }
  if (name == "arguments") {
    task.arguments = L"--other-installation";
    return !autostart::OwnsTask(identity, task);
  }
#ifdef _WIN32
  if (name == "native_hash") {
    return autostart::InstallationHash(L"C:\\Apps & Tools\\FlClash\\FlClash.exe") ==
               L"7c2bd91a33ca0799" &&
           autostart::InstallationHash(L"C:\\\u5e94\u7528 & Tools\\FlClash.exe") ==
               L"a907a4e11ae7fbe9";
  }
#endif
  return false;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc == 2 && Run(argv[1])) return 0;
  std::cerr << "Autostart cleanup ownership assertion failed\n";
  return 1;
}
