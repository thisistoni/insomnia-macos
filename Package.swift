// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Insomnia", platforms: [.macOS(.v14)],
  products: [.executable(name: "Insomnia", targets: ["Insomnia"])],
  targets: [
    .target(name: "InsomniaCore"),
    .executableTarget(name: "Insomnia", dependencies: ["InsomniaCore"]),
    .testTarget(name: "InsomniaCoreTests", dependencies: ["InsomniaCore"]),
  ])
