#include <gtest/gtest.h>

#include <map>
#include <stdexcept>
#include <string>

#include "proxy_ownership.h"

namespace proxy {
namespace {

const std::wstring kA = L"127.0.0.1:7890";
const std::wstring kB = L"127.0.0.1:7891";
const std::wstring kOther = L"127.0.0.1:1080";

TEST(ProxyOwnership, FailedPortChangeKeepsOldAndPendingTargets) {
  OwnedProxyServers recorded{kA};
  const bool result = ApplyOwnedProxy(recorded, kB,
      [&]() {
        EXPECT_EQ(recorded, (OwnedProxyServers{kA, kB}));
        return false;
      },
      [&](const auto& servers) { recorded = servers; return true; });
  EXPECT_FALSE(result);
  EXPECT_EQ(recorded, (OwnedProxyServers{kA, kB}));
}

TEST(ProxyOwnership, PartialRasFailureReclaimsBothTargetsButNotForeignProxy) {
  OwnedProxyServers recorded{kA};
  std::map<std::string, std::wstring> connections{
      {"default", kA}, {"ras", kA}, {"foreign", kOther}};
  auto persist = [&](const auto& servers) { recorded = servers; return true; };
  EXPECT_FALSE(ApplyOwnedProxy(recorded, kB, [&]() {
    connections["default"] = kB;
    return false;
  }, persist));
  EXPECT_TRUE(ReclaimOwnedProxies(recorded,
      [](const auto&) { return true; },
      [&](const auto& server) {
        for (auto& connection : connections) {
          if (connection.second == server) connection.second.clear();
        }
        return true;
      }, persist));
  EXPECT_TRUE(connections["default"].empty());
  EXPECT_TRUE(connections["ras"].empty());
  EXPECT_EQ(connections["foreign"], kOther);
  EXPECT_TRUE(recorded.empty());
}

TEST(ProxyOwnership, InterruptedApplyHasAlreadyPersistedBothTargets) {
  OwnedProxyServers recorded{kA};
  EXPECT_THROW(ApplyOwnedProxy(recorded, kB,
      []() -> bool { throw std::runtime_error("interrupted"); },
      [&](const auto& servers) { recorded = servers; return true; }),
      std::runtime_error);
  EXPECT_EQ(recorded, (OwnedProxyServers{kA, kB}));
}

TEST(ProxyOwnership, SuccessConvergesToNewTargetAndDoesNotReclaimOthers) {
  OwnedProxyServers recorded{kA};
  auto persist = [&](const auto& servers) { recorded = servers; return true; };
  EXPECT_TRUE(ApplyOwnedProxy(recorded, kB, []() { return true; }, persist));
  EXPECT_EQ(recorded, (OwnedProxyServers{kB}));
  std::set<std::wstring> cleared;
  EXPECT_TRUE(ReclaimOwnedProxies(recorded,
      [](const auto&) { return true; },
      [&](const auto& server) { cleared.insert(server); return true; }, persist));
  EXPECT_EQ(cleared, (std::set<std::wstring>{kB}));
  EXPECT_EQ(cleared.count(kA), 0u);
  EXPECT_EQ(cleared.count(kOther), 0u);
}

TEST(ProxyOwnership, PendingPersistenceFailureDoesNotChangeSystemSettings) {
  bool applied = false;
  EXPECT_FALSE(ApplyOwnedProxy(OwnedProxyServers{kA}, kB,
      [&]() { applied = true; return true; },
      [](const auto&) { return false; }));
  EXPECT_FALSE(applied);
}

TEST(ProxyOwnership, FailedConvergencePersistenceKeepsBothForLaterCleanup) {
  OwnedProxyServers recorded{kA};
  int writes = 0;
  EXPECT_TRUE(ApplyOwnedProxy(recorded, kB, []() { return true; },
      [&](const auto& servers) {
        if (++writes > 1) return false;
        recorded = servers;
        return true;
      }));
  EXPECT_EQ(recorded, (OwnedProxyServers{kA, kB}));
}

TEST(ProxyOwnership, LiveOrUnknownListenerIsNeverCleared) {
  OwnedProxyServers recorded{kA, kB};
  EXPECT_TRUE(ReclaimOwnedProxies(recorded,
      [](const auto&) { return false; },
      [](const auto&) { ADD_FAILURE(); return true; },
      [&](const auto& servers) { recorded = servers; return true; }));
  EXPECT_EQ(recorded, (OwnedProxyServers{kA, kB}));
}

TEST(ProxyOwnership, FailedConnectionCleanupRetainsOwnershipForRetry) {
  OwnedProxyServers recorded{kA, kB};
  EXPECT_FALSE(ReclaimOwnedProxies(recorded,
      [](const auto&) { return true; },
      [&](const auto& server) { return server != kA; },
      [&](const auto& servers) { recorded = servers; return true; }));
  EXPECT_EQ(recorded, (OwnedProxyServers{kA}));
}

}  // namespace
}  // namespace proxy
