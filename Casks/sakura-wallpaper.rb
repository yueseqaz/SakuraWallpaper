cask "sakura-wallpaper" do
  version "1.0.1"
  sha256 "650829b442722b3f3a5c575045a9e60a203c78ea6279536eb85424b998b65319"

  url "https://github.com/yueseqaz/SakuraWallpaper/releases/download/v#{version}/SakuraWallpaper.dmg"
  name "SakuraWallpaper"
  desc "Video and image wallpaper manager"
  homepage "https://github.com/yueseqaz/SakuraWallpaper"

  depends_on macos: :monterey

  app "SakuraWallpaper.app"
end
