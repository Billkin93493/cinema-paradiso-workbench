import AVFoundation
import CoreVideo
import Foundation

@main
struct ShotDetectorScoreProbe {
    private struct Signature {
        let histogram: [Float]
        let lumaHistogram: [Float]
        let spatialLuma: [Float]
        let spatialPattern: [UInt8]
        let brightness: Float
    }

    static func main() throws {
        guard CommandLine.arguments.count >= 4 else {
            throw NSError(
                domain: "ShotDetectorScoreProbe",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "需要影片路径、开始秒数和结束秒数"]
            )
        }
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let start = Double(CommandLine.arguments[2]) ?? 0
        let end = Double(CommandLine.arguments[3]) ?? start
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
        )
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { return }

        var previous: Signature?
        var recentScores: [Float] = []
        var results: [[String: Any]] = []
        while let sampleBuffer = output.copyNextSampleBuffer() {
            autoreleasepool {
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                let current = makeSignature(pixelBuffer)
                defer { previous = current }
                guard let previous else { return }
                let metrics = distance(previous, current)
                let adaptiveValue = adaptiveThreshold(recentScores)
                let averageBrightness = (previous.brightness + current.brightness) / 2
                let threshold: Float
                if averageBrightness < 0.08 {
                    threshold = min(adaptiveValue, 0.17)
                } else if averageBrightness < 0.18 {
                    threshold = min(adaptiveValue, 0.30)
                } else {
                    threshold = adaptiveValue
                }
                let recentWindow = recentScores.suffix(12)
                let recentMean = recentWindow.isEmpty
                    ? 0
                    : recentWindow.reduce(0, +) / Float(recentWindow.count)
                let recentPeak = recentWindow.max() ?? 0
                let recentElevatedCount = recentWindow.filter { $0 >= 0.12 }.count
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                if metrics.score >= 0.12 {
                    results.append([
                        "time": time,
                        "score": metrics.score,
                        "threshold": threshold,
                        "brightness": averageBrightness,
                        "distribution": metrics.distribution,
                        "spatial": metrics.spatial,
                        "pattern": metrics.pattern,
                        "accepted": metrics.score >= threshold,
                        "recentMean": recentMean,
                        "recentPeak": recentPeak,
                        "recentElevatedCount": recentElevatedCount,
                    ])
                }
                recentScores.append(min(metrics.score, 0.32))
                if recentScores.count > 100 {
                    recentScores.removeFirst(recentScores.count - 100)
                }
            }
        }
        let outputResults: [[String: Any]]
        if CommandLine.arguments.contains("--all") {
            outputResults = results
        } else {
            outputResults = Array(results.sorted {
                ($0["score"] as? Float ?? 0) > ($1["score"] as? Float ?? 0)
            }.prefix(80))
        }
        let outputData = try JSONSerialization.data(
            withJSONObject: outputResults,
            options: [.prettyPrinted, .sortedKeys]
        )
        print(String(data: outputData, encoding: .utf8)!)
    }

    private static func makeSignature(_ pixelBuffer: CVPixelBuffer) -> Signature {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return Signature(
                histogram: Array(repeating: 0, count: 64),
                lumaHistogram: Array(repeating: 0, count: 32),
                spatialLuma: [],
                spatialPattern: [],
                brightness: 0
            )
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let columns = 32
        let rows = 18
        var histogram = Array(repeating: Float(0), count: 64)
        var lumaHistogram = Array(repeating: Float(0), count: 32)
        var spatialLuma: [Float] = []
        spatialLuma.reserveCapacity(columns * rows)
        var brightness: Float = 0
        let sampleCount = Float(columns * rows)

        for row in 0..<rows {
            let y = ((row * 2 + 1) * height) / (rows * 2)
            for column in 0..<columns {
                let x = ((column * 2 + 1) * width) / (columns * 2)
                let offset = y * bytesPerRow + x * 4
                let blue = bytes[offset]
                let green = bytes[offset + 1]
                let red = bytes[offset + 2]
                let luma = (
                    0.2126 * Float(red)
                    + 0.7152 * Float(green)
                    + 0.0722 * Float(blue)
                ) / 255
                histogram[Int(red >> 6) * 16 + Int(green >> 6) * 4 + Int(blue >> 6)] += 1
                lumaHistogram[min(31, Int(luma * 32))] += 1
                spatialLuma.append(luma)
                brightness += luma
            }
        }
        histogram = histogram.map { $0 / sampleCount }
        lumaHistogram = lumaHistogram.map { $0 / sampleCount }
        brightness /= sampleCount
        return Signature(
            histogram: histogram,
            lumaHistogram: lumaHistogram,
            spatialLuma: spatialLuma,
            spatialPattern: spatialLuma.map { $0 >= brightness ? 1 : 0 },
            brightness: brightness
        )
    }

    private static func distance(
        _ first: Signature,
        _ second: Signature
    ) -> (score: Float, distribution: Float, spatial: Float, pattern: Float) {
        let histogramDistance = 1 - zip(first.histogram, second.histogram)
            .reduce(Float(0)) { $0 + min($1.0, $1.1) }
        let lumaHistogramDistance = 1 - zip(first.lumaHistogram, second.lumaHistogram)
            .reduce(Float(0)) { $0 + min($1.0, $1.1) }
        let spatialDistance = zip(first.spatialLuma, second.spatialLuma)
            .reduce(Float(0)) { $0 + abs($1.0 - $1.1) }
            / Float(first.spatialLuma.count)
        let mismatches = zip(first.spatialPattern, second.spatialPattern)
            .reduce(0) { $0 + ($1.0 == $1.1 ? 0 : 1) }
        let patternDistance = Float(mismatches) / Float(first.spatialPattern.count)
        let brightnessDistance = min(1, abs(first.brightness - second.brightness) * 2.2)
        let distribution = histogramDistance * 0.62
            + lumaHistogramDistance * 0.28
            + brightnessDistance * 0.10
        let averageBrightness = (first.brightness + second.brightness) / 2
        let spatialMultiplier: Float = averageBrightness < 0.18
            ? 6.0
            : (averageBrightness < 0.30 ? 4.2 : 3.4)
        let patternMultiplier: Float = averageBrightness < 0.18 ? 1.15 : 0.72
        let spatial = min(1, spatialDistance * spatialMultiplier)
        let pattern = min(1, patternDistance * patternMultiplier)
        return (max(distribution, spatial, pattern), distribution, spatial, pattern)
    }

    private static func adaptiveThreshold(_ recentScores: [Float]) -> Float {
        guard recentScores.count >= 20 else { return 0.28 }
        let mean = recentScores.reduce(0, +) / Float(recentScores.count)
        let variance = recentScores.reduce(Float(0)) {
            let delta = $1 - mean
            return $0 + delta * delta
        } / Float(recentScores.count)
        let deviation = sqrt(variance)
        return min(0.62, max(0.19, mean + max(0.105, deviation * 4.2)))
    }
}
