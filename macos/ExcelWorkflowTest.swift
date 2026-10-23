import AppKit
import Foundation

@main
struct ExcelWorkflowTest {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let outputDirectory = root.appendingPathComponent("tmp/xlsx", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let imageOne = root.appendingPathComponent("preview/assets/still-01.png").absoluteString
        let imageTwo = root.appendingPathComponent("preview/assets/still-07.png").absoluteString
        let notes = [
            "人物停在门口后没有立刻进入，镜头保留空间距离，让迟疑先于对白出现。",
            "",
            "固定机位让两人的停顿成为主要动作，背景亮度变化承担时间流逝。",
            "前景遮挡将视线切成两部分，人物虽然处在同一空间，关系仍然没有真正靠近。",
            "",
            "最后一个镜头在动作完成后继续停留，让空画面接住前面没有说完的情绪。",
        ]
        let sizes = ["全景", "中景", "中景", "近景", "特写", "全景"]
        let movements = ["固定", "推镜", "固定", "横移", "固定", "固定"]
        let shots: [[String: Any]] = (0..<6).map { index in
            let start = Double(index) * 6.5
            return [
                "key": "shot-\(index)",
                "number": index + 1,
                "start": start,
                "end": start + 6.5,
                "size": sizes[index],
                "angle": index == 3 ? "俯视" : "平视",
                "movement": movements[index],
                "dialogueText": index == 0
                    ? "我不知道你会不会来。\n原文：I didn't know if you'd come."
                    : (index == 1 ? "这是中文字幕。" : ""),
                "note": notes[index],
                "imageUrl": index == 0 ? imageOne : (index == 3 ? imageTwo : ""),
            ]
        }
        let report: [String: Any] = [
            "generatedDate": "2026/06/09",
            "project": [
                "name": "自动测试影片",
                "duration": 39.0,
                "mode": "local",
            ],
            "shots": shots,
            "noteCount": 4,
            "frameCount": 2,
        ]
        let destination = outputDirectory.appendingPathComponent(
            "自动测试影片-专业图文拉片表-\(UUID().uuidString.prefix(8)).xlsx"
        )
        try CinemaExcelExporter.export(
            report: report,
            destinationURL: destination,
            replaceExisting: false
        )
        let size = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        print("{\"file\":\"\(destination.path)\",\"shots\":6,\"images\":2,\"bytes\":\(size)}")
    }
}
