# proxy

FlClash's desktop system-proxy integration.

- Windows uses a Flutter method channel and WinINet settings.
- macOS uses `/usr/sbin/networksetup` for each active network service.
- Linux uses GNOME/MATE `gsettings` or KDE `kwriteconfig` based on the active
  desktop environment.

The public `Proxy` API validates the port, applies HTTP, HTTPS, and SOCKS
settings to `127.0.0.1`, and returns `false` when the selected platform backend
is unavailable or a command fails.

Windows ownership records retain old and pending targets before applying a new
port. Only a successful update of every connection reduces the record to the new
target. Stale cleanup matches recorded addresses exactly and keeps targets with
live listeners or failed connection queries for a later retry.

The ownership state tests run without Flutter or Windows APIs:

```sh
cmake -S test/native -B build/ownership
cmake --build build/ownership --config Debug
ctest --test-dir build/ownership -C Debug --output-on-failure
```

The cloud Windows job also runs this target. These tests cover state transitions;
WinINet, registry persistence and actual RAS settings still need Windows checks.
