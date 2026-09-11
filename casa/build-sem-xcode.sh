#!/usr/bin/env bash
# Compila o FineTune (github.com/ronitsingh10/FineTune, GPL-3) SEM Xcode — só Command Line Tools —
# e monta o FineTune.app pronto pra /Applications.
#
# Por quê existe: o repo só tem FineTune.xcodeproj; o Mac do Luciano não tem Xcode. O Package.swift
# em ./Package.swift espelha as build settings do xcodeproj; o strip-previews.py tira os #Preview
# (macro que exige plugin do Xcode). Assets.xcassets vira recursos soltos (PDF do ícone da barra +
# .icns gerado por iconutil).
#
# Uso:   build-sem-xcode.sh <clone-do-FineTune> <pasta-de-saída>
# Saída: <pasta-de-saída>/FineTune.app  (assinado ad-hoc, com entitlements do projeto)
set -euo pipefail

SRC="${1:?clone do FineTune (com ou sem patch)}"
OUT="${2:?pasta de saída}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$OUT/work"
APP="$OUT/FineTune.app"

echo "== 1/5 cópia de trabalho + Package.swift + strip de #Preview"
mkdir -p "$WORK"
rsync -a --delete --exclude .git --exclude .build "$SRC/" "$WORK/"   # .build do clone tem cache preso ao path dele
[ -f "$WORK/Package.swift" ] || cp "$HERE/../Package.swift" "$WORK/Package.swift"
( cd "$WORK" && swift package resolve >/dev/null )
chmod -R u+w "$WORK/.build/checkouts"
python3 "$HERE/strip-previews.py" "$WORK/FineTune" "$WORK/.build/checkouts"

echo "== 2/5 swift build -c release"
( cd "$WORK" && swift build -c release 2>&1 | grep -E "error|warning: unre|Build complete" ) || true
BIN="$WORK/.build/release/FineTune"
[ -x "$BIN" ] || { echo "FALHA: binário não gerado"; exit 1; }

echo "== 3/5 montando o bundle"
[ -d "$APP" ] && mv "$APP" "$OUT/FineTune.app.anterior-$(date +%H%M%S)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/FineTune"
cp "$WORK/FineTune/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.pdf" "$APP/Contents/Resources/MenuBarIcon.pdf"
cp -R "$WORK/.build/release/KeyboardShortcuts_KeyboardShortcuts.bundle" "$APP/Contents/Resources/"
cp -R "$WORK/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "$APP/Contents/Frameworks/"
# ícone do app: appiconset já usa os nomes que o iconutil espera
ICONSET="$OUT/FineTune.iconset"; mkdir -p "$ICONSET"
cp "$WORK/FineTune/Assets.xcassets/fineTuneIcon.appiconset/"icon_*.png "$ICONSET/"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/FineTune.icns"
cp "$WORK/FineTune/FineTune.entitlements" "$OUT/FineTune.entitlements"

echo "== 4/5 Info.plist (base do projeto + chaves que o Xcode geraria)"
python3 - "$WORK/FineTune/Info.plist" "$APP/Contents/Info.plist" <<'EOF'
import plistlib, sys
base = plistlib.load(open(sys.argv[1], 'rb'))
base.update({
    'CFBundleDevelopmentRegion': 'en',
    'CFBundleExecutable': 'FineTune',
    'CFBundleIdentifier': 'com.finetuneapp.FineTune',
    'CFBundleName': 'FineTune',
    'CFBundleDisplayName': 'FineTune',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '1.9.0',
    'CFBundleVersion': '1',
    'CFBundleIconFile': 'FineTune',
    'CFBundleInfoDictionaryVersion': '6.0',
    'LSMinimumSystemVersion': '15.4',
    'LSApplicationCategoryType': 'public.app-category.utilities',
    'NSPrincipalClass': 'NSApplication',
    'NSHighResolutionCapable': True,
    'NSHumanReadableCopyright': '',
    # build local: não deixa o Sparkle trocar por conta própria (assinatura ad-hoc ≠ Developer ID);
    # checagem manual em Settings › Updates continua possível.
    'SUEnableAutomaticChecks': False,
    'LLBuildNote': 'build local sem Xcode (~/Projects/FineTune, branch casa) — patches: ver git log upstream/main..casa',
})
plistlib.dump(base, open(sys.argv[2], 'wb'))
EOF

echo "== 5/5 assinatura ad-hoc com entitlements do projeto"
codesign --force --deep --sign - --entitlements "$OUT/FineTune.entitlements" "$APP" 2>&1 | grep -v "replacing existing" || true
codesign --verify --deep --strict "$APP" && echo "codesign: OK"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -E "audio-input|bluetooth|network" | sed 's/^/  entitlement: /'
echo "PRONTO: $APP"
