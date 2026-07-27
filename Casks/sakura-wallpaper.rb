cask "sakura-wallpaper" do
  version "1.0.2"
  sha256 "90b04d46888bef4d8c5993f959f3ec21fd0c9fe587448a64311781e47724e7bf"

  url "https://github.com/yueseqaz/SakuraWallpaper/releases/download/v#{version}/SakuraWallpaper.dmg"
  name "SakuraWallpaper"
  desc "Video and image wallpaper manager"
  homepage "https://github.com/yueseqaz/SakuraWallpaper"

  depends_on macos: :monterey

  app "SakuraWallpaper.app"
end
