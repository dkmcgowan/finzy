cask "finzy" do
  version "0.1.1"
  sha256 "518f862bd828df6d3ce313c2e4e6dd24f0ade7568e313489b23f4625544d0805"

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
