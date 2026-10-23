import Foundation

@main
struct BackupWorkflowTest {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let testRoot = root
            .appendingPathComponent("tmp/backup-workflow-\(UUID().uuidString)", isDirectory: true)
        let source = testRoot.appendingPathComponent("source", isDirectory: true)
        let restored = testRoot.appendingPathComponent("restored", isDirectory: true)
        let backupURL = testRoot.appendingPathComponent("导演资料备份.cpbak")
        let legacyBackupURL = testRoot.appendingPathComponent("旧版导演资料备份.cpbak")
        let legacyRestored = testRoot.appendingPathComponent("legacy-restored", isDirectory: true)
        let freshRestored = testRoot.appendingPathComponent("fresh-restored", isDirectory: true)
        let frameDirectory = source.appendingPathComponent("archive-frames", isDirectory: true)
        let clipDirectory = source.appendingPathComponent("archive-clips", isDirectory: true)
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: clipDirectory, withIntermediateDirectories: true)

        let analysis: [String: Any] = [
            "mode": "manual",
            "cutPoints": [0.0, 4.0, 9.0, 14.0],
            "shotData": [
                "shot-0": [
                    "size": "中景",
                    "angle": "平视",
                    "movement": "固定",
                    "note": "自动测试导演笔记",
                ],
            ],
        ]
        let analysisData = try JSONSerialization.data(withJSONObject: analysis)
        let project: [String: Any] = [
            "name": "自动测试影片",
            "filePath": "/Users/test/Movies/自动测试影片.mov",
            "size": 123_456,
            "duration": 14.0,
            "updatedAt": "2026-06-09T10:00:00Z",
            "analysisJSON": String(data: analysisData, encoding: .utf8)!,
        ]
        try jsonData(project).write(
            to: source.appendingPathComponent("recent-project.json"),
            options: .atomic
        )

        let frameImage = Data("frame-original-quality".utf8)
        let clipImage = Data("clip-original-quality".utf8)
        try frameImage.write(to: frameDirectory.appendingPathComponent("frame-1.jpg"))
        try clipImage.write(to: clipDirectory.appendingPathComponent("clip-1.jpg"))

        let frame: [String: Any] = [
            "id": "frame-1",
            "projectName": "自动测试影片",
            "sourceFilePath": "/Users/test/Movies/自动测试影片.mov",
            "shotKey": "shot-0",
            "shotNumber": 1,
            "start": 0.0,
            "end": 4.0,
            "capturedAt": 2.0,
            "imageFileName": "frame-1.jpg",
            "note": "静帧笔记",
            "tags": ["中景", "固定"],
            "createdAt": "2026-06-09T10:01:00Z",
        ]
        let clip: [String: Any] = [
            "id": "clip-1",
            "projectName": "自动测试影片",
            "sourceFilePath": "/Users/test/Movies/自动测试影片.mov",
            "shotKey": "shot-0",
            "shotNumber": 1,
            "start": 1.0,
            "end": 3.5,
            "capturedAt": 1.0,
            "imageFileName": "clip-1.jpg",
            "note": "片段笔记",
            "tags": ["中景", "固定"],
            "createdAt": "2026-06-09T10:02:00Z",
        ]
        try jsonData([frame]).write(
            to: source.appendingPathComponent("archive-frames.json"),
            options: .atomic
        )
        try jsonData([clip]).write(
            to: source.appendingPathComponent("archive-clips.json"),
            options: .atomic
        )
        _ = try CinemaBackupManager.createBackup(
            supportDirectoryURL: source,
            destinationURL: legacyBackupURL
        )
        let collection: [String: Any] = [
            "id": "collection-1",
            "name": "测试灵感",
            "description": "测试收藏夹",
            "createdAt": "2026-06-09T10:03:00Z",
            "updatedAt": "2026-06-09T10:03:00Z",
            "lastUsedAt": "2026-06-09T10:03:00Z",
        ]
        let memberships: [[String: Any]] = [
            [
                "id": "membership-frame-1",
                "collectionId": "collection-1",
                "itemType": "frame",
                "itemId": "frame-1",
                "addedAt": "2026-06-09T10:04:00Z",
            ],
            [
                "id": "membership-clip-1",
                "collectionId": "collection-1",
                "itemType": "clip",
                "itemId": "clip-1",
                "addedAt": "2026-06-09T10:05:00Z",
            ],
        ]
        let note: [String: Any] = [
            "id": "note-1",
            "title": "人物关系",
            "body": "测试文字卡片不会覆盖现有内容。",
            "collectionIds": ["collection-1"],
            "createdAt": "2026-06-09T10:06:00Z",
            "updatedAt": "2026-06-09T10:06:00Z",
        ]
        try jsonData([collection]).write(
            to: source.appendingPathComponent("inspiration-collections.json"),
            options: .atomic
        )
        try jsonData(memberships).write(
            to: source.appendingPathComponent("inspiration-memberships.json"),
            options: .atomic
        )
        try jsonData([note]).write(
            to: source.appendingPathComponent("inspiration-notes.json"),
            options: .atomic
        )

        let created = try CinemaBackupManager.createBackup(
            supportDirectoryURL: source,
            destinationURL: backupURL
        )
        let inspected = try CinemaBackupManager.inspectBackup(at: backupURL)
        let legacyInspected = try CinemaBackupManager.inspectBackup(at: legacyBackupURL)
        let legacyRestore = try CinemaBackupManager.restoreBackup(
            from: legacyBackupURL,
            supportDirectoryURL: legacyRestored
        )
        let freshRestore = try CinemaBackupManager.restoreBackup(
            from: backupURL,
            supportDirectoryURL: freshRestored
        )
        try FileManager.default.createDirectory(at: restored, withIntermediateDirectories: true)
        let existingCollection: [String: Any] = [
            "id": "existing-collection",
            "name": "测试灵感",
            "description": "保留电脑中已有说明",
            "createdAt": "2026-06-08T10:00:00Z",
            "updatedAt": "2026-06-08T10:00:00Z",
            "lastUsedAt": "2026-06-08T10:00:00Z",
        ]
        try jsonData([existingCollection]).write(
            to: restored.appendingPathComponent("inspiration-collections.json"),
            options: .atomic
        )
        let firstRestore = try CinemaBackupManager.restoreBackup(
            from: backupURL,
            supportDirectoryURL: restored
        )
        let secondRestore = try CinemaBackupManager.restoreBackup(
            from: backupURL,
            supportDirectoryURL: restored
        )

        let restoredFrame = try Data(
            contentsOf: restored.appendingPathComponent("archive-frames/frame-1.jpg")
        )
        let restoredClip = try Data(
            contentsOf: restored.appendingPathComponent("archive-clips/clip-1.jpg")
        )
        let restoredCollections = try jsonArray(
            from: restored.appendingPathComponent("inspiration-collections.json")
        )
        let restoredMemberships = try jsonArray(
            from: restored.appendingPathComponent("inspiration-memberships.json")
        )
        let restoredNotes = try jsonArray(
            from: restored.appendingPathComponent("inspiration-notes.json")
        )
        let backupText = try String(contentsOf: backupURL, encoding: .utf8)
        let containsOriginalVideoBytes = backupText.contains("original-video-binary")
        let success = created.projectCount == 1
            && inspected.shotCount == 3
            && inspected.collectionCount == 1
            && inspected.inspirationItemCount == 2
            && inspected.noteCount == 1
            && legacyInspected.collectionCount == 0
            && legacyInspected.inspirationItemCount == 0
            && legacyInspected.noteCount == 0
            && legacyRestore.addedProjects == 1
            && legacyRestore.addedFrames == 1
            && legacyRestore.addedClips == 1
            && freshRestore.addedCollections == 1
            && freshRestore.addedInspirationItems == 2
            && freshRestore.addedNotes == 1
            && firstRestore.addedProjects == 1
            && firstRestore.addedFrames == 1
            && firstRestore.addedClips == 1
            && firstRestore.addedCollections == 0
            && firstRestore.addedInspirationItems == 2
            && firstRestore.addedNotes == 1
            && secondRestore.addedFrames == 0
            && secondRestore.addedClips == 0
            && secondRestore.addedCollections == 0
            && secondRestore.addedInspirationItems == 0
            && secondRestore.addedNotes == 0
            && secondRestore.skippedItems == 7
            && restoredCollections.count == 1
            && restoredCollections.first?["id"] as? String == "existing-collection"
            && restoredMemberships.count == 2
            && restoredMemberships.allSatisfy {
                $0["collectionId"] as? String == "existing-collection"
            }
            && restoredNotes.count == 1
            && restoredNotes.first?["collectionIds"] as? [String] == ["existing-collection"]
            && restoredFrame == frameImage
            && restoredClip == clipImage
            && !containsOriginalVideoBytes

        let result: [String: Any] = [
            "success": success,
            "backup": backupURL.path,
            "projects": inspected.projectCount,
            "frames": inspected.frameCount,
            "clips": inspected.clipCount,
            "shots": inspected.shotCount,
            "collections": inspected.collectionCount,
            "inspirationItems": inspected.inspirationItemCount,
            "notes": inspected.noteCount,
            "secondRestoreSkipped": secondRestore.skippedItems,
            "sameNameCollectionMerged": restoredCollections.count == 1,
            "freshCollectionRestored": freshRestore.addedCollections == 1,
            "legacyBackupSupported": legacyRestore.addedFrames == 1
                && legacyRestore.addedClips == 1,
            "imageQualityPreserved": restoredFrame == frameImage && restoredClip == clipImage,
            "containsOriginalVideoBytes": containsOriginalVideoBytes,
        ]
        print(String(data: try jsonData(result), encoding: .utf8)!)
        if !success {
            throw CinemaBackupError.invalid
        }
    }

    private static func jsonData(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private static func jsonArray(from url: URL) throws -> [[String: Any]] {
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }
}
