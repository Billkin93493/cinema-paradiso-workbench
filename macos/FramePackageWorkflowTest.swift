import Foundation

@main
struct FramePackageWorkflowTest {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let outputDirectory = root.appendingPathComponent("tmp/frame-packages", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let imageOne = root.appendingPathComponent("preview/assets/still-01.png")
        let imageTwo = root.appendingPathComponent("preview/assets/still-07.png")
        let frames: [[String: Any]] = [
            [
                "projectName": "自动测试影片",
                "sourceFilePath": "/Users/test/Movies/自动测试影片.mov",
                "shotNumber": 1,
                "start": 0.0,
                "end": 6.5,
                "capturedAt": 2.48,
                "imageUrl": imageOne.absoluteString,
                "note": "人物停在门口，空间距离先于对白出现。",
                "tags": ["中景", "固定"],
            ],
            [
                "projectName": "自动测试影片",
                "sourceFilePath": "/Users/test/Movies/自动测试影片.mov",
                "shotNumber": 4,
                "start": 19.5,
                "end": 26.0,
                "capturedAt": 22.2,
                "imageUrl": imageTwo.absoluteString,
                "note": "前景遮挡将视线切成两部分。",
                "tags": ["近景", "前景遮挡"],
            ],
        ]
        let package: [String: Any] = [
            "project": [
                "name": "自动测试影片",
                "filePath": "/Users/test/Movies/自动测试影片.mov",
            ],
            "frames": frames,
        ]
        let destination = outputDirectory.appendingPathComponent(
            "自动测试影片-导演静帧资料包-\(UUID().uuidString.prefix(8)).zip"
        )
        try CinemaFramePackageExporter.export(
            package: package,
            destinationURL: destination,
            replaceExisting: false
        )

        let size = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        print("{\"file\":\"\(destination.path)\",\"frames\":2,\"bytes\":\(size)}")
    }
}
