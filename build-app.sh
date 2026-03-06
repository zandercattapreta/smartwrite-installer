#!/bin/bash
# build-app.sh — SmartWrite Installer — Script de empacotamento do .app
# Uso: ./build-app.sh
set -e

APP_NAME="SmartWrite Installer"
BUNDLE="${APP_NAME}.app"
EXEC_NAME="SmartWriteInstaller"
ICONSET_DIR="/tmp/SmartWriteInstaller.iconset"
SRC_ICON="_resources/icon_512x512@2x.png"

echo "🔨 Compilando projeto (release)..."
swift build -c release

echo "📦 Montando bundle..."
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"

cp ".build/release/${EXEC_NAME}" "${BUNDLE}/Contents/MacOS/"
cp "Sources/SmartWriteInstaller/Info.plist" "${BUNDLE}/Contents/"

# Copiar resources do SPM (assets bundle)
ASSETS_BUNDLE=$(find .build/release -name "*.bundle" | head -1)
if [ -n "${ASSETS_BUNDLE}" ]; then
  cp -r "${ASSETS_BUNDLE}" "${BUNDLE}/Contents/Resources/"
fi

# Gerar e copiar ícone
if [ -f "${SRC_ICON}" ]; then
  echo "🎨 Gerando ícone..."
  mkdir -p "${ICONSET_DIR}"
  sips -z 16 16   "${SRC_ICON}" --out "${ICONSET_DIR}/icon_16x16.png"    > /dev/null
  sips -z 32 32   "${SRC_ICON}" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null
  sips -z 32 32   "${SRC_ICON}" --out "${ICONSET_DIR}/icon_32x32.png"    > /dev/null
  sips -z 64 64   "${SRC_ICON}" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null
  sips -z 128 128 "${SRC_ICON}" --out "${ICONSET_DIR}/icon_128x128.png"  > /dev/null
  sips -z 256 256 "${SRC_ICON}" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
  sips -z 256 256 "${SRC_ICON}" --out "${ICONSET_DIR}/icon_256x256.png"  > /dev/null
  sips -z 512 512 "${SRC_ICON}" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
  sips -z 512 512 "${SRC_ICON}" --out "${ICONSET_DIR}/icon_512x512.png"  > /dev/null
  sips -z 1024 1024 "${SRC_ICON}" --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null
  iconutil -c icns "${ICONSET_DIR}" -o "${BUNDLE}/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${BUNDLE}/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${BUNDLE}/Contents/Info.plist"
fi

echo "✅ ${BUNDLE} gerado com sucesso!"
echo "👉 Para abrir: open \"${BUNDLE}\""
