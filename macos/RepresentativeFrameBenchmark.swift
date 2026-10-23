import AppKit
import Foundation

@main
struct RepresentativeFrameBenchmarkRunner {
    static func main() throws {
        guard CommandLine.arguments.count >= 4 else {
            fputs("usage: benchmark VIDEO ANALYSIS_JSON OUTPUT [LIMIT]\n", stderr)
            exit(2)
        }

        let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let analysisURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
        let limit = CommandLine.arguments.count > 4
            ? Int(CommandLine.arguments[4])
            : nil

        let projectData = try Data(contentsOf: analysisURL)
        let projectObject = try JSONSerialization.jsonObject(with: projectData) as? [String: Any]
        guard
            let analysisText = projectObject?["analysisJSON"] as? String,
            let analysisData = analysisText.data(using: .utf8),
            let analysisObject = try JSONSerialization.jsonObject(with: analysisData) as? [String: Any],
            let cutPoints = analysisObject["cutPoints"] as? [Double]
        else {
            throw NSError(domain: "RepresentativeFrameBenchmark", code: 1)
        }

        let allShots = cutPoints.indices.dropLast().map { index in
            let start = cutPoints[index]
            return RepresentativeFrameGenerator.Shot(
                key: "shot-\(Int((start * 1000).rounded()))",
                start: start,
                end: cutPoints[index + 1]
            )
        }
        let shots = limit.map { Array(allShots.prefix($0)) } ?? allShots
        let startedAt = Date()
        let results = try RepresentativeFrameGenerator.generate(
            videoURL: videoURL,
            shots: shots,
            rootDirectoryURL: outputURL
        ) { percent in
            if percent % 10 == 0 {
                print("PROGRESS \(percent)%")
            }
        }

        print(
            "REPRESENTATIVE_FRAME_BENCHMARK_OK "
                + "requested=\(shots.count) generated=\(results.count) "
                + "elapsed=\(Date().timeIntervalSince(startedAt))"
        )
    }
}
