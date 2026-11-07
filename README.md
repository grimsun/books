# Bookflow

A SwiftUI iPhone book tracker with Open Library search and local reading data.

Open `ios/BookFlowApp/BookFlowApp.xcodeproj`, select the `BookFlowApp` scheme,
and run on an iPhone simulator. Search uses Open Library; Home recommendations,
curated lists, Popular, and reading goals are still sample data. Shelves, progress,
onboarding preferences, and reading rhythm are saved on this device.

Run the data and repository regression tests:

```sh
swift test --package-path ios
```

To include the optional live Open Library search/detail/save check:

```sh
BOOKFLOW_LIVE_TESTS=1 swift test --package-path ios
```

Run the simulator UI tests with Product > Test in Xcode, or:

```sh
xcodebuild -project ios/BookFlowApp/BookFlowApp.xcodeproj \
  -scheme BookFlowApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

UI tests use separate local storage and deterministic book fixtures. They cover
onboarding, search, saving a book, updating progress, settings, and app relaunch.
