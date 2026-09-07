// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BeaconKit",
    // macOS 26 for the on-device speech stack, which is what makes dictation
    // possible without bundling a model. SwiftPM has no `.v26` case yet, so the
    // version is given as a string.
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "BeaconKit", targets: ["BeaconKit"])
    ],
    targets: [
        .target(name: "BeaconKit"),
        // The macOS app. Packaged into a bundle by Scripts/build-mac-app.sh,
        // which is what gives it the Info.plist that EventKit requires.
        .executableTarget(name: "BeaconApp", dependencies: ["BeaconKit"]),
        // Prints one worked plan, for eyeballing behaviour by hand.
        .executableTarget(name: "BeaconDemo", dependencies: ["BeaconKit"]),
        .testTarget(name: "BeaconKitTests", dependencies: ["BeaconKit"]),
    ]
)
