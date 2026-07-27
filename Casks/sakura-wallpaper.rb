cask "sakura-wallpaper" do
  version "1.0.3"
  sha256 "91c77cd0b47acf9b14c8b438c9eb9132d0b3f7257c2f0e5d824665cd13a24e0c"

  url "https://github.com/yueseqaz/SakuraWallpaper/releases/download/v#{version}/SakuraWallpaper.dmg"
  name "SakuraWallpaper"
  desc "Video and image wallpaper manager"
  homepage "https://github.com/yueseqaz/SakuraWallpaper"

  depends_on macos: :monterey

  app "SakuraWallpaper.app"
end
