// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "365WeaponsAdmin",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WeaponsAdmin",
            targets: ["WeaponsAdmin"]),
    ],
    targets: [
        .target(
            name: "WeaponsAdmin",
            dependencies: [],
            path: "365WeaponsAdmin"),
        .testTarget(
            name: "WeaponsAdminTests",
            dependencies: ["WeaponsAdmin"],
            path: "365WeaponsAdminTests"),
    ]
)
