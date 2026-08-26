// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "MacOSMicPriority",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "MacOSMicPriority", targets: ["MacOSMicPriority"])
  ],
  targets: [
    .executableTarget(
      name: "MacOSMicPriority",
      path: "Sources/MacOSMicPriority",
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("CoreAudio"),
        .linkedFramework("ServiceManagement"),
        .linkedFramework("SwiftUI"),
      ]
    )
  ]
)
