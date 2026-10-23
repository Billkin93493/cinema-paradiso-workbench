import AppKit
import Foundation

@main
struct RepresentativeFrameWorkflowTestRunner {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let videoURL = URL(
            fileURLWithPath: "/System/Library/CoreServices/ControlCenter.app/Contents/Resources/BentoGalleryIntroduction.mov"
        )
        let outputURL = root.appendingPathComponent("tmp/representative-frame-test", isDirectory: true)
        let shots = [
            RepresentativeFrameGenerator.Shot(key: "shot-3000", start: 3, end: 6),
            RepresentativeFrameGenerator.Shot(key: "shot-6000", start: 6, end: 9),
        ]

        let results = try RepresentativeFrameGenerator.generate(
            videoURL: videoURL,
            shots: shots,
            rootDirectoryURL: outputURL
        ) { _ in }
        guard
            results.count == 2,
            results.values.allSatisfy({
                $0.source == "auto"
                    && FileManager.default.fileExists(atPath: $0.imageURL.path)
            }),
            let first = results["shot-3000"],
            first.capturedAt >= 3,
            first.capturedAt <= 6,
            let firstImageData = try? Data(contentsOf: first.imageURL)
        else {
            throw NSError(domain: "RepresentativeFrameTest", code: 1)
        }

        let manual = try RepresentativeFrameGenerator.saveManualFrame(
            imageDataURL: "data:image/jpeg;base64,\(firstImageData.base64EncodedString())",
            shotKey: "shot-3000",
            capturedAt: 4.8,
            sourcePath: videoURL.path,
            rootDirectoryURL: outputURL
        )
        guard
            manual.source == "manual",
            abs(manual.capturedAt - 4.8) < 0.001,
            FileManager.default.fileExists(atPath: manual.imageURL.path)
        else {
            throw NSError(domain: "RepresentativeFrameTest", code: 2)
        }

        print("REPRESENTATIVE_FRAME_TEST_OK auto=\(results.count) manual=\(manual.source)")
    }
}
