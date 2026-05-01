cask "finzy" do
  version "0.4.2"
  sha256 "c16dc2ec70b5805a91d62a07777a6d67bcb2ff63c214743932feed3d72b75606"

  url "https://github.com/dkmcgowan/finzy/releases/download/#{version}/finzy-macos.dmg"
  name "Finzy"
  desc "Modern Jellyfin client built with Flutter"
  homepage "https://github.com/dkmcgowan/finzy"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true

  app "Finzy.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Finzy.app"],
                   sudo: false
  end

  uninstall quit: "com.dkmcgowan.finzy"

  zap trash: [
    "~/Library/Application Support/com.dkmcgowan.finzy",
    "~/Library/Caches/com.dkmcgowan.finzy",
    "~/Library/HTTPStorages/com.dkmcgowan.finzy",
    "~/Library/Preferences/com.dkmcgowan.finzy.plist",
    "~/Library/Saved Application State/com.dkmcgowan.finzy.savedState",
    "~/Library/WebKit/com.dkmcgowan.finzy",
  ]
end
