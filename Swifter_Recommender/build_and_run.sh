#!/bin/zsh
set -e

clear
cd ~/Projects/Swifter/SwifterCLI/Swifter_Recommender

# Kill any previous Orion AI Recommender instances.
pkill -f OrionAIRecommender 2>/dev/null || true
pkill -f Swifter_Recommender 2>/dev/null || true
sleep 0.5

TOTAL=$(find . \
  -path "./.build" -prune -o \
  -path "./.swiftpm" -prune -o \
  -path "./Data/SourceTruth" -prune -o \
  -type f \
  \( -name "*.swift" -o -name "*.json" -o -name "*.csv" -o -name "*.html" -o -name "Package.swift" -o -name "*.sh" \) \
  -print0 | xargs -0 wc -l | tail -1 | awk '{print $1}')

python3 - <<PY
from pathlib import Path
import re

total = "$TOTAL"
p = Path("Sources/Swifter_Recommender/main.swift")
s = p.read_text()

s = re.sub(r'@State private var generatedLines = \d+', f'@State private var generatedLines = {total}', s)

s = re.sub(
    r'Text\("TECH STACK:.*?MACOS APP BUNDLE"\)[\s\S]*?\.minimumScaleFactor\(0\.55\)',
    '''Text("Swift • SwiftUI • Python • JSON • CSV • HTML • Git • SHA-256")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)''',
    s
)

p.write_text(s)
print("✅ Generated Lines updated:", total)
PY

pkill -f OrionAIRecommender 2>/dev/null || true

unset TOOLCHAINS
export TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault

/usr/bin/xcrun --toolchain XcodeDefault swift build

APP="$HOME/Desktop/Orion AI Recommender.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/debug/Swifter_Recommender "$APP/Contents/MacOS/OrionAIRecommender"
chmod +x "$APP/Contents/MacOS/OrionAIRecommender"

open "$APP"
