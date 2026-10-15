#ifndef RUNNER_AUTOSTART_CLEANUP_H_
#define RUNNER_AUTOSTART_CLEANUP_H_

#include <string>

#ifdef _WIN32
#include <windows.h>
#endif

namespace autostart {

struct Identity {
  std::wstring sid;
  std::wstring installation;
  std::wstring executable;

  std::wstring TaskName() const {
    return L"FlClash_AutoLaunch_" + sid + L"_" + installation;
  }

  std::wstring Source() const {
    return L"com.follow.clash.autostart.v1/" + sid + L"/" + installation;
  }
};

struct Task {
  std::wstring name;
  std::wstring source;
  std::wstring principal_sid;
  std::wstring trigger_sid;
  std::wstring executable;
  std::wstring arguments;
  int action_count = 0;
  int trigger_count = 0;
  bool interactive = false;
  bool least_privilege = false;
  bool logon_trigger = false;
  bool exec_action = false;
};

inline bool OwnsTask(const Identity& identity, const Task& task) {
  return !identity.sid.empty() && identity.installation.size() == 16 &&
         !identity.executable.empty() && task.name == identity.TaskName() &&
         task.source == identity.Source() && task.principal_sid == identity.sid &&
         task.trigger_sid == identity.sid &&
         task.executable == identity.executable && task.arguments.empty() &&
         task.action_count == 1 && task.trigger_count == 1 && task.interactive &&
         task.least_privilege && task.logon_trigger && task.exec_action;
}

#ifdef _WIN32
unsigned int CleanupMessage();
bool RemoveCurrentUserTask();
bool RemoveOriginalUserTask(HWND running);
std::wstring InstallationHash(const std::wstring& executable);
#endif

}  // namespace autostart

#endif  // RUNNER_AUTOSTART_CLEANUP_H_
