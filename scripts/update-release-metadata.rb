#!/usr/bin/env ruby

version, sha256, mode = ARGV

unless version&.match?(/\A\d+\.\d+\.\d+(?:[._-][0-9A-Za-z.-]+)?\z/)
  abort "Usage: #{$PROGRAM_NAME} VERSION SHA256 [--sync-project-version]"
end

unless sha256&.match?(/\A[0-9a-f]{64}\z/)
  abort "SHA256 must be a lowercase 64-character hexadecimal digest"
end

unless mode.nil? || mode == "--sync-project-version"
  abort "Unknown option: #{mode}"
end

def replace!(path, pattern, replacement)
  content = File.read(path)
  abort "Expected release field was not found in #{path}" unless content.match?(pattern)

  File.write(path, content.sub(pattern, replacement))
end

replace!("Casks/sakura-wallpaper.rb", /^  version "[^"]+"$/, %(  version "#{version}"))
replace!("Casks/sakura-wallpaper.rb", /^  sha256 "[0-9a-f]+"$/, %(  sha256 "#{sha256}"))

if mode == "--sync-project-version"
  replace!("build.sh", /^DEFAULT_APP_VERSION="[^"]+"$/, %(DEFAULT_APP_VERSION="#{version}"))
  replace!("README.md", /^Current version: `v[^`]+`$/, %(Current version: `v#{version}`))
  replace!("README_CN.md", /^当前版本：`v[^`]+`$/, %(当前版本：`v#{version}`))
end
