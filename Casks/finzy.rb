cask "finzy" do
  version "0.2.2"
  sha256 "5bb38fd976827c5be26f22e47921b1c9441165f8f28cfc7c19636edcb2873973"

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
