import Foundation

private struct LargeProjectRecord: Codable {
    var name: String
    var filePath: String
    var size: UInt64
    var duration: Double
    var updatedAt: String
    var analysisJSON: String?
}

@main
struct LargeProjectPersistenceTest {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let testDirectory = root
            .appendingPathComponent("tmp/large-persistence-\(UUID().uuidString)", isDirectory: true)
        let projectURL = testDirectory.appendingPathComponent("recent-project.json")
        let interruptedTemporaryURL = testDirectory.appendingPathComponent(".recent-project.interrupted")
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )

        let firstAnalysis = try makeAnalysis(note: "异常中断前已保存的导演笔记")
        let firstRecord = LargeProjectRecord(
            name: "两小时压力测试影片",
            filePath: "/tmp/large-project-test.mov",
            size: 12_345_678,
            duration: 7200,
            updatedAt: "2026-06-14T10:00:00Z",
            analysisJSON: firstAnalysis
        )
        try JSONEncoder().encode(firstRecord).write(to: projectURL, options: .atomic)

        try Data("{\"name\":\"未完成".utf8).write(to: interruptedTemporaryURL)
        let reopenedAfterInterruption = try JSONDecoder().decode(
            LargeProjectRecord.self,
            from: Data(contentsOf: projectURL)
        )
        let interruptionAnalysis = try decodeAnalysis(reopenedAfterInterruption.analysisJSON)

        let secondAnalysis = try makeAnalysis(note: "重新打开后继续完成的导演笔记")
        let secondRecord = LargeProjectRecord(
            name: firstRecord.name,
            filePath: firstRecord.filePath,
            size: firstRecord.size,
            duration: firstRecord.duration,
            updatedAt: "2026-06-14T10:05:00Z",
            analysisJSON: secondAnalysis
        )
        try JSONEncoder().encode(secondRecord).write(to: projectURL, options: .atomic)
        let reopenedAfterSave = try JSONDecoder().decode(
            LargeProjectRecord.self,
            from: Data(contentsOf: projectURL)
        )
        let savedAnalysis = try decodeAnalysis(reopenedAfterSave.analysisJSON)

        let interruptionNote = note(at: 899, analysis: interruptionAnalysis)
        let savedNote = note(at: 899, analysis: savedAnalysis)
        let cutPoints = savedAnalysis["cutPoints"] as? [Double] ?? []
        let shotData = savedAnalysis["shotData"] as? [String: Any] ?? [:]
        let result: [String: Any] = [
            "duration": reopenedAfterSave.duration,
            "shots": max(0, cutPoints.count - 1),
            "shotRecords": shotData.count,
            "interruptedSaveKeptPreviousData":
                interruptionNote == "异常中断前已保存的导演笔记",
            "continuedSaveReopened":
                savedNote == "重新打开后继续完成的导演笔记",
            "projectBytes": try Data(contentsOf: projectURL).count,
        ]
        let success = reopenedAfterSave.duration == 7200
            && cutPoints.count == 1201
            && shotData.count == 1200
            && interruptionNote == "异常中断前已保存的导演笔记"
            && savedNote == "重新打开后继续完成的导演笔记"
        print(String(
            data: try JSONSerialization.data(
                withJSONObject: result,
                options: [.prettyPrinted, .sortedKeys]
            ),
            encoding: .utf8
        )!)
        if !success {
            throw NSError(
                domain: "LargeProjectPersistenceTest",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "长片项目保存恢复检查失败"]
            )
        }
    }

    private static func makeAnalysis(note: String) throws -> String {
        let duration = 7200.0
        let shotCount = 1200
        let cutPoints = (0...shotCount).map {
            Double($0) * duration / Double(shotCount)
        }
        var shotData: [String: Any] = [:]
        for index in 0..<shotCount {
            let key = "shot-\(Int(cutPoints[index] * 1000))"
            shotData[key] = [
                "size": index % 4 == 0 ? "全景" : "中景",
                "angle": index % 7 == 0 ? "俯拍" : "平视",
                "movement": index % 5 == 0 ? "跟拍" : "固定",
                "note": index == 899 ? note : "",
            ]
        }
        let analysis: [String: Any] = [
            "mode": "manual",
            "cutPoints": cutPoints,
            "shotData": shotData,
            "cutConfidence": [:],
            "representativeFrames": [:],
        ]
        let data = try JSONSerialization.data(withJSONObject: analysis)
        return String(data: data, encoding: .utf8)!
    }

    private static func decodeAnalysis(_ value: String?) throws -> [String: Any] {
        guard
            let value,
            let data = value.data(using: .utf8),
            let analysis = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw NSError(
                domain: "LargeProjectPersistenceTest",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "保存的拉片资料无法重新读取"]
            )
        }
        return analysis
    }

    private static func note(at index: Int, analysis: [String: Any]) -> String {
        guard
            let cutPoints = analysis["cutPoints"] as? [Double],
            cutPoints.indices.contains(index),
            let shotData = analysis["shotData"] as? [String: Any],
            let record = shotData["shot-\(Int(cutPoints[index] * 1000))"] as? [String: Any]
        else {
            return ""
        }
        return record["note"] as? String ?? ""
    }
}
