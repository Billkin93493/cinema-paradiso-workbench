import AVFoundation
import Foundation
import Vision

@main
struct ShotFeaturePrintProbe {
    static func main() throws {
        guard CommandLine.arguments.count >= 3 else {
            throw NSError(
                domain: "ShotFeaturePrintProbe",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "用法：ShotFeaturePrintProbe 影片路径 切点秒数列表 [前后间隔]"
                ]
            )
        }

        let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let cutTimes = CommandLine.arguments[2]
            .split(separator: ",")
            .compactMap { Double($0) }
        let offset = CommandLine.arguments.count >= 4
            ? max(0.04, Double(CommandLine.arguments[3]) ?? 0.12)
            : 0.12
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var results: [[String: Any]] = []
        for cutTime in cutTimes {
            let farBeforeFeature = try featurePrint(
                frame(
                    generator,
                    at: max(0, cutTime - offset * 3)
                )
            )
            let beforeFeature = try featurePrint(
                frame(
                    generator,
                    at: max(0, cutTime - offset)
                )
            )
            let afterFeature = try featurePrint(
                frame(generator, at: cutTime + offset)
            )
            let farAfterFeature = try featurePrint(
                frame(generator, at: cutTime + offset * 3)
            )
            let beforeMotion = try distance(farBeforeFeature, beforeFeature)
            let cutDistance = try distance(beforeFeature, afterFeature)
            let afterMotion = try distance(afterFeature, farAfterFeature)
            results.append([
                "time": cutTime,
                "offset": offset,
                "beforeMotion": beforeMotion,
                "distance": cutDistance,
                "afterMotion": afterMotion,
                "motionRatio":
                    cutDistance / max(0.01, (beforeMotion + afterMotion) / 2),
            ])
        }

        let data = try JSONSerialization.data(
            withJSONObject: results,
            options: [.prettyPrinted, .sortedKeys]
        )
        print(String(data: data, encoding: .utf8)!)
    }

    private static func featurePrint(
        _ image: CGImage
    ) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let result = request.results?.first as? VNFeaturePrintObservation else {
            throw NSError(
                domain: "ShotFeaturePrintProbe",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "画面相似度分析失败"]
            )
        }
        return result
    }

    private static func frame(
        _ generator: AVAssetImageGenerator,
        at seconds: Double
    ) throws -> CGImage {
        try generator.copyCGImage(
            at: CMTime(seconds: seconds, preferredTimescale: 600),
            actualTime: nil
        )
    }

    private static func distance(
        _ first: VNFeaturePrintObservation,
        _ second: VNFeaturePrintObservation
    ) throws -> Float {
        var value: Float = 0
        try first.computeDistance(&value, to: second)
        return value
    }
}
