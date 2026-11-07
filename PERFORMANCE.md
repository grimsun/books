# Performance Verification

## Changes

- Home keeps its small set of sections mounted with stable heights. It does not
  recycle entire variable-height sections while scrolling.
- Search and Library use native List row reuse and a shared book-card component.
- Home selections and feed data survive tab changes and navigation. Unchanged
  library revisions and search queries do not trigger reloads or list replacement.
- Detail screens begin with the selected Book, then refresh saved state and metadata.
- Image I/O downsampling, decompression, file access, JSON decoding, and library
  transactions run on worker actors/tasks instead of the UI actor.
- All surfaces share decoded cover bitmaps. Visible cache hits render immediately.
  Smaller cards reuse a suitable larger bitmap instead of decoding another copy.
- Cache budgets are 24 MiB decoded images, 4 MiB compressed images, and 128 MiB
  HTTP disk storage with no additional HTTP memory cache. NSCache responds to
  memory pressure, and the app explicitly clears decoded cache on memory warnings.
- Shared image requests are coalesced and cancelled when their last reader leaves.
- Five bundled seed covers make initial Home independent of network latency.

## Measurements

iPhone 17 Pro Simulator, iOS 26.2, Xcode 27.2. Three iterations of four Home swipes
after warming the feed. Decimal MB below are derived from XCTest's kB metrics.

| Configuration | Peak Physical Memory | App CPU Time Per Swipe Sequence |
| --- | ---: | ---: |
| Original Debug baseline | 82.96 MB | 1.083 s |
| Optimized Debug | 72.25 MB | 1.303 s |
| Optimized Release | 70.66 MB | 1.200 s |

The memory reduction is measurable. Warm-scroll CPU did not improve; do not infer
an FPS improvement from these results or compare different configurations as if
they were the same benchmark. Stable anchors and removal of blocking work address
layout jumps and responsiveness separately from aggregate CPU usage.

Release launch-to-responsive-first-frame averaged 1.58 s with clean app data.
These are process launches under XCTest, not OS/filesystem-cache-cold launches.

Checks include 21 core tests, a real Open Library search/detail/save, shared image
cache/cancellation tests, a 1,000-book Library stress test, retained tab positions,
repeated Home scrolling, push/pop restoration, and zero attempted network requests
for the seeded Home feed. Anchor checks compare position and dimensions within
two points instead of merely verifying that content exists.

Animation Hitches is unsupported on this simulator. A short Time Profiler trace
was captured, but simulator CPU/anchor checks do not certify physical-device frame
pacing or 60/120 FPS. Profile a Release build on an iPhone for that assessment.

## Reproducing

```sh
BOOKFLOW_LIVE_TESTS=1 swift test --package-path ios
xcodebuild -project ios/BookFlowApp/BookFlowApp.xcodeproj \
  -scheme BookFlowApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

UI tests use a separate data store. The large-library fixture is enabled only in
Debug test launches. Launch metrics also run in Release; reset flags do not delete
the normal app's data in that configuration. XCTest results contain the individual
launch, CPU, memory, and scroll-duration measurements. Scroll duration is not FPS.
