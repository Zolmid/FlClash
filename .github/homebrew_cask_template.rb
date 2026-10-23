cask "zolnit" do
  version "VERSION"

  on_macos do
    arch arm: "arm64", intel: "amd64"

    sha256 arm:   "ARM_SHA256",
           intel: "AMD_SHA256"

    url "https://link.zolmid.com"
  end

  name "ZolNit"
  desc "Multi-platform proxy client based on ClashMeta"
  homepage "https://link.zolmid.com"
  disable! date: "2026-10-21", because: "no verified website release is available"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  app "ZolNit.app"

  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-rd", "com.apple.quarantine", "{{appdir}}/ZolNit.app"],
        writable_paths: ["ZolNit.app"],
        writable_base:  :appdir
  end

  uninstall quit: "com.zolmid.zolnit"

  zap trash: [
    "~/Library/Application Support/com.zolmid.zolnit",
    "~/Library/Caches/com.zolmid.zolnit",
    "~/Library/Preferences/com.zolmid.zolnit.plist",
    "~/Library/Saved Application State/com.zolmid.zolnit.savedState",
  ]
end
