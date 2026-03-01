cask "finzy" do
  version "0.1.2"
  sha256 "054f319343969dba560cf2d8873c0bfc2b8c42f1486b60305aa58cc1ca827390"

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
