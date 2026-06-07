#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project IrregularMeasureMetronome.xcodeproj \
  -scheme IrregularMeasureMetronome \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
