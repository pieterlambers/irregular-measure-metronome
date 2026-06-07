# Agent Instructions

## Running Tests

When running the iOS unit tests from the command line, use the repo test script:

```sh
./scripts/test-unit.sh
```

Run this script with escalated permissions on the first attempt. The iOS simulator test run needs access to CoreSimulatorService and Xcode's user DerivedData/log directories, which are outside the normal workspace sandbox.

The script pins full Xcode and the known working simulator destination:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project IrregularMeasureMetronome.xcodeproj \
  -scheme IrregularMeasureMetronome \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

Do not use the default Command Line Tools `xcodebuild` or an unspecified simulator destination for this project's iOS test target.
