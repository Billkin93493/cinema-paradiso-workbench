import AVFoundation
import Foundation

@main
struct ImageGeneratorBenchmark {
    static func main() throws {
        guard CommandLine.arguments.count >= 2 else {
            fputs("需要提供影片路径\n", stderr)
            exit(2)
        }

        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let asset = AVURLAsset(url: url)
        let duration = asset.duration.seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 20)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 20)

        let step = 0.25
        let startedAt = Date()
        var count = 0
        var time = 0.0
        while time < duration {
            autoreleasepool {
                let requested = CMTime(seconds: time, preferredTimescale: 600)
                if (try? generator.copyCGImage(at: requested, actualTime: nil)) != nil {
                    count += 1
                }
            }
            time += step
        }

        let elapsed = Date().timeIntervalSince(startedAt)
        let value: [String: Any] = [
            "file": url.lastPathComponent,
            "duration": duration,
            "images": count,
            "elapsed": elapsed,
            "estimatedTwoHourSeconds": duration > 0
                ? elapsed * (7200 / duration)
                : 0,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.prettyPrinted, .sortedKeys]
        )
        print(String(data: data, encoding: .utf8)!)
    }
}
