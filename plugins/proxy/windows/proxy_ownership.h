#ifndef FLUTTER_PLUGIN_PROXY_OWNERSHIP_H_
#define FLUTTER_PLUGIN_PROXY_OWNERSHIP_H_

#include <set>
#include <string>

namespace proxy {

using OwnedProxyServers = std::set<std::wstring>;

template <typename Apply, typename Persist>
bool ApplyOwnedProxy(OwnedProxyServers owned, const std::wstring& target,
                     Apply apply, Persist persist) {
  owned.insert(target);
  if (!persist(owned)) return false;
  if (!apply()) return false;
  persist(OwnedProxyServers{target});
  return true;
}

template <typename Released, typename Clear, typename Persist>
bool ReclaimOwnedProxies(OwnedProxyServers owned, Released released,
                         Clear clear, Persist persist) {
  bool success = true;
  for (auto entry = owned.begin(); entry != owned.end();) {
    if (!released(*entry)) {
      ++entry;
    } else if (clear(*entry)) {
      entry = owned.erase(entry);
    } else {
      success = false;
      ++entry;
    }
  }
  return persist(owned) && success;
}

}  // namespace proxy

#endif
