#include "autostart_cleanup.h"

#include <windows.h>
#include <bcrypt.h>
#include <sddl.h>
#include <taskschd.h>
#include <wrl/client.h>

#include <array>
#include <vector>

namespace autostart {
namespace {

using Microsoft::WRL::ComPtr;

class Bstr {
 public:
  Bstr() = default;
  explicit Bstr(const std::wstring& text) : value(SysAllocString(text.c_str())) {}
  ~Bstr() { SysFreeString(value); }
  BSTR* Put() { return &value; }
  std::wstring Text() const { return value ? value : L""; }
  BSTR value = nullptr;
};

std::wstring NormalizePath(std::wstring path) {
  for (auto& character : path) {
    if (character == L'/') character = L'\\';
  }
  if (path.empty()) return path;
  std::wstring normalized(path.size(), L'\0');
  if (LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_LOWERCASE, path.data(),
                    static_cast<int>(path.size()), normalized.data(),
                    static_cast<int>(normalized.size()), nullptr, nullptr,
                    0) == 0) return L"";
  return normalized;
}

std::wstring ExecutablePath() {
  std::vector<wchar_t> path(32768);
  const DWORD length = GetModuleFileNameW(nullptr, path.data(),
                                         static_cast<DWORD>(path.size()));
  if (length == 0 || length == path.size()) return L"";
  return NormalizePath(std::wstring(path.data(), length));
}

std::wstring CurrentSid() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return L"";
  DWORD length = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &length);
  std::vector<unsigned char> bytes(static_cast<size_t>(length));
  const BOOL read = GetTokenInformation(token, TokenUser, bytes.data(), length,
                                        &length);
  CloseHandle(token);
  if (!read) return L"";
  LPWSTR sid = nullptr;
  if (!ConvertSidToStringSidW(
          reinterpret_cast<TOKEN_USER*>(bytes.data())->User.Sid, &sid)) {
    return L"";
  }
  const std::wstring result(sid);
  LocalFree(sid);
  return result;
}

bool ReadTask(IRegisteredTask* registered, Task* task) {
  ComPtr<ITaskDefinition> definition;
  ComPtr<IRegistrationInfo> registration;
  ComPtr<IPrincipal> principal;
  ComPtr<IActionCollection> actions;
  ComPtr<ITriggerCollection> triggers;
  if (FAILED(registered->get_Definition(&definition)) ||
      FAILED(definition->get_RegistrationInfo(&registration)) ||
      FAILED(definition->get_Principal(&principal)) ||
      FAILED(definition->get_Actions(&actions)) ||
      FAILED(definition->get_Triggers(&triggers))) return false;

  Bstr name, source, principal_sid, trigger_sid, command, arguments;
  LONG action_count = 0, trigger_count = 0;
  TASK_LOGON_TYPE logon;
  TASK_RUNLEVEL_TYPE run_level;
  if (FAILED(registered->get_Name(name.Put())) ||
      FAILED(registration->get_Source(source.Put())) ||
      FAILED(principal->get_UserId(principal_sid.Put())) ||
      FAILED(principal->get_LogonType(&logon)) ||
      FAILED(principal->get_RunLevel(&run_level)) ||
      FAILED(actions->get_Count(&action_count)) ||
      FAILED(triggers->get_Count(&trigger_count)) || action_count != 1 ||
      trigger_count != 1) return false;

  ComPtr<IAction> action;
  ComPtr<IExecAction> exec;
  ComPtr<ITrigger> trigger;
  ComPtr<ILogonTrigger> logon_trigger;
  TASK_ACTION_TYPE action_type;
  TASK_TRIGGER_TYPE2 trigger_type;
  if (FAILED(actions->get_Item(1, &action)) ||
      FAILED(action->get_Type(&action_type)) || action_type != TASK_ACTION_EXEC ||
      FAILED(action.As(&exec)) || FAILED(exec->get_Path(command.Put())) ||
      FAILED(exec->get_Arguments(arguments.Put())) ||
      FAILED(triggers->get_Item(1, &trigger)) ||
      FAILED(trigger->get_Type(&trigger_type)) ||
      trigger_type != TASK_TRIGGER_LOGON || FAILED(trigger.As(&logon_trigger)) ||
      FAILED(logon_trigger->get_UserId(trigger_sid.Put()))) return false;

  *task = {name.Text(), source.Text(), principal_sid.Text(), trigger_sid.Text(),
           NormalizePath(command.Text()), arguments.Text(),
           static_cast<int>(action_count), static_cast<int>(trigger_count),
           logon == TASK_LOGON_INTERACTIVE_TOKEN, run_level == TASK_RUNLEVEL_LUA,
           true, true};
  return true;
}

bool RemoveTask(const Identity& identity) {
  ComPtr<ITaskService> scheduler;
  if (FAILED(CoCreateInstance(CLSID_TaskScheduler, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&scheduler)))) return false;
  VARIANT empty;
  VariantInit(&empty);
  if (FAILED(scheduler->Connect(empty, empty, empty, empty))) return false;
  ComPtr<ITaskFolder> folder;
  Bstr root(L"\\");
  if (FAILED(scheduler->GetFolder(root.value, &folder))) return false;
  ComPtr<IRegisteredTask> registered;
  Bstr name(identity.TaskName());
  const HRESULT found = folder->GetTask(name.value, &registered);
  if (found == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) ||
      found == HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND)) return true;
  if (FAILED(found)) return false;
  Task task;
  return ReadTask(registered.Get(), &task) && OwnsTask(identity, task) &&
         SUCCEEDED(folder->DeleteTask(name.value, 0));
}

bool SameInstallation(HWND window, const std::wstring& executable) {
  DWORD pid = 0;
  GetWindowThreadProcessId(window, &pid);
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return false;
  std::vector<wchar_t> path(32768);
  DWORD length = static_cast<DWORD>(path.size());
  const BOOL read = QueryFullProcessImageNameW(process, 0, path.data(), &length);
  CloseHandle(process);
  return read && NormalizePath(std::wstring(path.data(), length)) == executable;
}

}  // namespace

std::wstring InstallationHash(const std::wstring& executable) {
  const std::wstring normalized = NormalizePath(executable);
  const int length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                        normalized.data(),
                                        static_cast<int>(normalized.size()),
                                        nullptr, 0, nullptr, nullptr);
  if (length <= 0) return L"";
  std::vector<unsigned char> bytes(static_cast<size_t>(length));
  if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, normalized.data(),
                          static_cast<int>(normalized.size()),
                          reinterpret_cast<char*>(bytes.data()), length,
                          nullptr, nullptr) != length) return L"";
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  BCRYPT_HASH_HANDLE hash = nullptr;
  std::array<unsigned char, 32> digest{};
  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr,
                                  0) != 0) return L"";
  bool valid = BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0) == 0;
  if (valid) {
    valid = BCryptHashData(hash, bytes.data(), static_cast<ULONG>(bytes.size()),
                           0) == 0 &&
            BCryptFinishHash(hash, digest.data(),
                             static_cast<ULONG>(digest.size()), 0) == 0;
    BCryptDestroyHash(hash);
  }
  BCryptCloseAlgorithmProvider(algorithm, 0);
  if (!valid) return L"";
  constexpr wchar_t hex[] = L"0123456789abcdef";
  std::wstring result;
  for (int index = 0; index < 8; ++index) {
    result += hex[digest[index] >> 4];
    result += hex[digest[index] & 15];
  }
  return result;
}

unsigned int CleanupMessage() {
  const auto installation = InstallationHash(ExecutablePath());
  if (installation.empty()) return 0;
  return RegisterWindowMessageW(
      (L"FlClash.RemoveScheduledAutostart." + installation).c_str());
}

bool RemoveCurrentUserTask() {
  const auto executable = ExecutablePath();
  const auto sid = CurrentSid();
  const auto installation = InstallationHash(executable);
  if (executable.empty() || sid.empty() || installation.empty()) return false;
  const HRESULT initialized = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(initialized) && initialized != RPC_E_CHANGED_MODE) return false;
  const bool removed = RemoveTask({sid, installation, executable});
  if (SUCCEEDED(initialized)) CoUninitialize();
  return removed;
}

bool RemoveOriginalUserTask(HWND running) {
  if (running) {
    if (SameInstallation(running, ExecutablePath())) {
      const UINT message = CleanupMessage();
      DWORD_PTR removed = 0;
      return message != 0 && SendMessageTimeoutW(
              running, message, 0, 0, SMTO_ABORTIFHUNG, 3000, &removed) != 0 &&
          removed != 0;
    }
  }
  return RemoveCurrentUserTask();
}

}  // namespace autostart
