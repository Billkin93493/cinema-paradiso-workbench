import Foundation

@main
struct ShotDetectorBenchmark {
    static func main() throws {
        guard CommandLine.arguments.count >= 2 else {
            fputs("需要提供影片路径\n", stderr)
            exit(2)
        }

        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let startedAt = Date()
        let result = try LocalShotDetector.analyze(url: url) { percent, seconds in
            if percent % 10 == 0 {
                fputs("PROGRESS \(percent)% \(String(format: "%.1f", seconds))s\n", stderr)
            }
        }
        let elapsed = Date().timeIntervalSince(startedAt)
        let candidateTimes = result.candidates.map(\.time)
        let boundaries = [0.0] + candidateTimes + [result.duration]
        let shotDurations = zip(boundaries, boundaries.dropFirst()).map { $1 - $0 }
        let sortedDurations = shotDurations.sorted()
        let averageShotDuration = shotDurations.isEmpty
            ? 0
            : shotDurations.reduce(0, +) / Double(shotDurations.count)
        let medianShotDuration = sortedDurations.isEmpty
            ? 0
            : sortedDurations[sortedDurations.count / 2]
        let longestShotRanges = zip(boundaries, boundaries.dropFirst())
            .map { ["start": $0, "end": $1, "duration": $1 - $0] }
            .sorted {
                ($0["duration"] ?? 0) > ($1["duration"] ?? 0)
            }
            .prefix(10)
        let highConfidenceCount = result.candidates.filter { $0.confidence >= 0.8 }.count
        let timestampsAreOrdered = zip(candidateTimes, candidateTimes.dropFirst())
            .allSatisfy { $0 < $1 }
        var value: [String: Any] = [
            "file": url.lastPathComponent,
            "duration": result.duration,
            "frames": result.frameCount,
            "cuts": result.candidates.count,
            "shots": shotDurations.count,
            "averageShotDuration": averageShotDuration,
            "medianShotDuration": medianShotDuration,
            "shortestShotDuration": sortedDurations.first ?? 0,
            "longestShotDuration": sortedDurations.last ?? 0,
            "longestShotRanges": Array(longestShotRanges),
            "highConfidenceCuts": highConfidenceCount,
            "reviewSuggestedCuts": result.candidates.count - highConfidenceCount,
            "timestampsAreOrdered": timestampsAreOrdered,
            "elapsed": elapsed,
            "speed": result.duration > 0 ? result.duration / elapsed : 0,
            "estimatedTwoHourSeconds": result.duration > 0
                ? elapsed * (7200 / result.duration)
                : 0,
        ]
        if CommandLine.arguments.contains("--include-candidates") {
            value["candidates"] = result.candidates.map {
                [
                    "time": $0.time,
                    "confidence": $0.confidence,
                ]
            }
        }
        let data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.prettyPrinted, .sortedKeys]
        )
        print(String(data: data, encoding: .utf8)!)
    }
}
