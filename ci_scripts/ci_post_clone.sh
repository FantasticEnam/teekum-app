#!/bin/sh

# Hentikan eksekusi jika ada satu perintah yang gagal
set -e

# 1. Tambahkan PATH agar brew & xcodegen dapat ditemukan
export PATH=$PATH:/opt/homebrew/bin:/usr/local/bin
export HOMEBREW_NO_AUTO_UPDATE=1

# 2. Pindah direktori ke root utama repositori
cd "$(dirname "$0")/.." || exit 1

# 3. Install XcodeGen
brew install xcodegen

# 4. Sinkronisasi Build Number otomatis dari Xcode Cloud (jika berjalan di CI)
if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "Xcode Cloud build detected. Updating CURRENT_PROJECT_VERSION to $CI_BUILD_NUMBER"
    sed -i '' "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: \"$CI_BUILD_NUMBER\"/" project.yml
fi

# 5. (Opsional) Jika di masa depan memerlukan Config.xcconfig dari Environment Variable di Xcode Cloud:
# mkdir -p Teekum/Teekum/Config
# cat <<EOF > Teekum/Teekum/Config/Config.xcconfig
# API_KEY = $API_KEY
# EOF

# 6. Generate Xcode Project
xcodegen generate

# 7. Aktifkan SPM auto-resolution (Xcode Cloud menonaktifkannya by default)
defaults write com.apple.dt.Xcode IDEDisableAutomaticPackageResolution -bool NO || true
defaults write com.apple.dt.Xcode IDEPackageOnlyUseVersionsFromResolvedFile -bool NO || true

# 8. Resolve SPM dependencies dan generate Package.resolved
xcodebuild -resolvePackageDependencies -project Teekum.xcodeproj -scheme Teekum
