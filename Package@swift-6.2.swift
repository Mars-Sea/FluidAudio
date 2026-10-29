// swift-tools-version: 6.2
import PackageDescription
import Foundation

// GotIt fork: Tools 6.2+ manifest, identical to Package.swift plus the `TTS`
// and `Diarizer` traits. Keep the two in sync.
// The NemoTextProcessing engine (prebuilt Rust staticlib, ~28 MB for iOS arm64)
// is removed in this fork; FluidAudio's `canImport(CNemoTextProcessing)` guards
// make TTS frontends and `TextNormalizer` pass text through unchanged without it.

let package = Package(
    name: "FluidAudio",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v2),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "FluidAudio",
            targets: ["FluidAudio"]
        ),
        .executable(
            name: "fluidaudiocli",
            targets: ["FluidAudioCLI"]
        ),
    ],
    traits: [
        // Opt out of whole subsystems for apps that never reach them (#990):
        //   .package(url: ..., traits: [])            // ASR/VAD only
        //   .package(url: ..., traits: ["Diarizer"])  // ASR/VAD + diarization
        .trait(
            name: "TTS",
            description: "Text-to-speech backends (Kokoro, PocketTTS, LuxTTS, ...) and their bundled G2P resources."
        ),
        .trait(
            name: "Diarizer",
            description: "Speaker diarization (pyannote, Sortformer, LS-EEND, Nemotron 3)."
        ),
        // GotIt fork: Diarizer is off by default (GotIt never uses speaker diarization).
        .default(enabledTraits: ["TTS"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FluidAudio",
            dependencies: [
                "FastClusterWrapper",
                "MachTaskSelfWrapper",
                .target(name: "LuxTtsG2pResources", condition: .when(traits: ["TTS"])),
            ],
            path: "Sources/FluidAudio",
            exclude: ["ASR/Parakeet/Unified/benchmark.md"]
        ),
        // Separate target so the ~1 MB G2P bundle drops out with the `TTS` trait.
        .target(
            name: "LuxTtsG2pResources",
            path: "Sources/LuxTtsG2pResources",
            resources: [
                // Keep .process: .copy of a Resources-named directory breaks Apple code signing on iOS.
                .process("Resources")
            ]
        ),
        .target(
            name: "FastClusterWrapper",
            path: "Sources/FastClusterWrapper",
            publicHeadersPath: "include"
        ),
        .target(
            name: "MachTaskSelfWrapper",
            path: "Sources/MachTaskSelfWrapper",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "FluidAudioCLI",
            dependencies: ["FluidAudio"],
            path: "Sources/FluidAudioCLI",
            exclude: ["README.md"],
            resources: [
                .process("Utils/english.json")
            ]
        ),
        .testTarget(
            name: "FluidAudioTests",
            dependencies: [
                "FluidAudio",
                "FluidAudioCLI",
            ],
            resources: [
                .process("TTS/LuxTts/Resources"),
                .process("TTS/PocketTTS/Fixtures"),
                // Real recordings (cleared for public release by the speaker) for the
                // streaming final-window regression, issue #855.
                .copy("ASR/Parakeet/SlidingWindow/Fixtures"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
