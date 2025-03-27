// swift-tools-version:5.10
import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "Archivist",
  platforms: [.macOS(.v11)],
  products: [
    .library(name: "Archivist", targets: ["Archivist"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"),
  ],
  targets: [
    .target(
      name: "Archivist",
      dependencies: [
        .target(name: "ArchivistMacros"),
      ]),
    .macro(
      name: "ArchivistMacros",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      ]),
    .testTarget(
      name: "ArchivistTests",
      dependencies: [
        .target(name: "Archivist"),
      ]),
  ])
