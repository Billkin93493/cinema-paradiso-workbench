import Foundation

enum CinemaBackupError: Error {
    case empty
    case invalid
    case unsupported
    case missingImage
}

struct CinemaBackupSummary: Codable {
    var createdAt: String
    var projectCount: Int
    var frameCount: Int
    var clipCount: Int
    var shotCount: Int
    var collectionCount: Int
    var inspirationItemCount: Int
    var noteCount: Int

    var bridgeValue: [String: Any] {
        [
            "createdAt": createdAt,
            "projectCount": projectCount,
            "frameCount": frameCount,
            "clipCount": clipCount,
            "shotCount": shotCount,
            "collectionCount": collectionCount,
            "inspirationItemCount": inspirationItemCount,
            "noteCount": noteCount,
        ]
    }
}

struct CinemaRestoreResult {
    var summary: CinemaBackupSummary
    var addedProjects: Int
    var addedFrames: Int
    var addedClips: Int
    var addedCollections: Int
    var addedInspirationItems: Int
    var addedNotes: Int
    var skippedItems: Int

    var bridgeValue: [String: Any] {
        var value = summary.bridgeValue
        value["addedProjects"] = addedProjects
        value["addedFrames"] = addedFrames
        value["addedClips"] = addedClips
        value["addedCollections"] = addedCollections
        value["addedInspirationItems"] = addedInspirationItems
        value["addedNotes"] = addedNotes
        value["skippedItems"] = skippedItems
        return value
    }
}

private struct CinemaBackupEntry: Codable {
    var path: String
    var data: Data
}

private struct CinemaBackupDocument: Codable {
    var format: String
    var version: Int
    var createdAt: String
    var entries: [CinemaBackupEntry]
}

enum CinemaBackupManager {
    private static let format = "cinema-paradiso-director-backup"
    private static let version = 1
    private static let projectPath = "recent-project.json"
    private static let frameIndexPath = "archive-frames.json"
    private static let clipIndexPath = "archive-clips.json"
    private static let collectionIndexPath = "inspiration-collections.json"
    private static let membershipIndexPath = "inspiration-memberships.json"
    private static let noteIndexPath = "inspiration-notes.json"

    static func createBackup(
        supportDirectoryURL: URL,
        destinationURL: URL
    ) throws -> CinemaBackupSummary {
        let fileManager = FileManager.default
        let indexPaths = [
            projectPath,
            frameIndexPath,
            clipIndexPath,
            collectionIndexPath,
            membershipIndexPath,
            noteIndexPath,
        ]
        var entries: [CinemaBackupEntry] = []

        for relativePath in indexPaths {
            let sourceURL = supportDirectoryURL.appendingPathComponent(relativePath)
            if let data = try? Data(contentsOf: sourceURL) {
                let backupData = relativePath == projectPath
                    ? sanitizedProjectBackupData(data)
                    : data
                entries.append(CinemaBackupEntry(path: relativePath, data: backupData))
            }
        }

        entries.append(contentsOf: try imageEntries(
            indexData: entryData(frameIndexPath, in: entries),
            directoryName: "archive-frames",
            supportDirectoryURL: supportDirectoryURL
        ))
        entries.append(contentsOf: try imageEntries(
            indexData: entryData(clipIndexPath, in: entries),
            directoryName: "archive-clips",
            supportDirectoryURL: supportDirectoryURL
        ))

        guard !entries.isEmpty else {
            throw CinemaBackupError.empty
        }

        let document = CinemaBackupDocument(
            format: format,
            version: version,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destinationURL, options: .atomic)
        return try summary(for: document)
    }

    static func inspectBackup(at url: URL) throws -> CinemaBackupSummary {
        try summary(for: readDocument(at: url))
    }

    static func restoreBackup(
        from backupURL: URL,
        supportDirectoryURL: URL
    ) throws -> CinemaRestoreResult {
        let document = try readDocument(at: backupURL)
        let summary = try summary(for: document)
        let entries = Dictionary(uniqueKeysWithValues: document.entries.map { ($0.path, $0.data) })
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )

        var addedProjects = 0
        var skippedItems = 0
        if let backupProjectData = entries[projectPath] {
            let currentProjectURL = supportDirectoryURL.appendingPathComponent(projectPath)
            if let currentProjectData = try? Data(contentsOf: currentProjectURL) {
                if try mergeProject(
                    currentData: currentProjectData,
                    backupData: backupProjectData,
                    destinationURL: currentProjectURL
                ) {
                    addedProjects = 1
                } else {
                    skippedItems += 1
                }
            } else {
                try backupProjectData.write(to: currentProjectURL, options: .atomic)
                addedProjects = 1
            }
        }

        let frameMerge = try mergeArchive(
            indexPath: frameIndexPath,
            directoryName: "archive-frames",
            backupEntries: entries,
            supportDirectoryURL: supportDirectoryURL,
            duplicateKey: frameDuplicateKey
        )
        let clipMerge = try mergeArchive(
            indexPath: clipIndexPath,
            directoryName: "archive-clips",
            backupEntries: entries,
            supportDirectoryURL: supportDirectoryURL,
            duplicateKey: clipDuplicateKey
        )
        let collectionMerge = try mergeCollections(
            backupEntries: entries,
            supportDirectoryURL: supportDirectoryURL
        )
        let membershipMerge = try mergeMemberships(
            backupEntries: entries,
            supportDirectoryURL: supportDirectoryURL,
            collectionIdMap: collectionMerge.idMap
        )
        let noteMerge = try mergeNotes(
            backupEntries: entries,
            supportDirectoryURL: supportDirectoryURL,
            collectionIdMap: collectionMerge.idMap
        )

        return CinemaRestoreResult(
            summary: summary,
            addedProjects: addedProjects,
            addedFrames: frameMerge.added,
            addedClips: clipMerge.added,
            addedCollections: collectionMerge.added,
            addedInspirationItems: membershipMerge.added,
            addedNotes: noteMerge.added,
            skippedItems: skippedItems
                + frameMerge.skipped
                + clipMerge.skipped
                + collectionMerge.skipped
                + membershipMerge.skipped
                + noteMerge.skipped
        )
    }

    private static func readDocument(at url: URL) throws -> CinemaBackupDocument {
        let data = try Data(contentsOf: url)
        let document: CinemaBackupDocument
        do {
            document = try JSONDecoder().decode(CinemaBackupDocument.self, from: data)
        } catch {
            throw CinemaBackupError.invalid
        }
        guard document.format == format else {
            throw CinemaBackupError.invalid
        }
        guard document.version == version else {
            throw CinemaBackupError.unsupported
        }
        let uniquePaths = Set(document.entries.map(\.path))
        guard
            !document.entries.isEmpty,
            uniquePaths.count == document.entries.count,
            document.entries.allSatisfy({ isAllowedPath($0.path) })
        else {
            throw CinemaBackupError.invalid
        }
        return document
    }

    private static func summary(for document: CinemaBackupDocument) throws -> CinemaBackupSummary {
        let entries = Dictionary(uniqueKeysWithValues: document.entries.map { ($0.path, $0.data) })
        return CinemaBackupSummary(
            createdAt: document.createdAt,
            projectCount: entries[projectPath] == nil ? 0 : 1,
            frameCount: jsonArray(from: entries[frameIndexPath]).count,
            clipCount: jsonArray(from: entries[clipIndexPath]).count,
            shotCount: shotCount(from: entries[projectPath]),
            collectionCount: jsonArray(from: entries[collectionIndexPath]).count,
            inspirationItemCount: Set<String>(
                jsonArray(from: entries[membershipIndexPath]).compactMap { record in
                    guard
                        let itemType = record["itemType"] as? String,
                        let itemId = record["itemId"] as? String,
                        !itemType.isEmpty,
                        !itemId.isEmpty
                    else {
                        return nil
                    }
                    return "\(itemType):\(itemId)"
                }
            ).count,
            noteCount: jsonArray(from: entries[noteIndexPath]).count
        )
    }

    private static func imageEntries(
        indexData: Data?,
        directoryName: String,
        supportDirectoryURL: URL
    ) throws -> [CinemaBackupEntry] {
        try jsonArray(from: indexData).compactMap { record in
            guard
                let fileName = safeFileName(record["imageFileName"] as? String),
                !fileName.isEmpty
            else {
                return nil
            }
            let sourceURL = supportDirectoryURL
                .appendingPathComponent(directoryName, isDirectory: true)
                .appendingPathComponent(fileName)
            guard let data = try? Data(contentsOf: sourceURL) else {
                throw CinemaBackupError.missingImage
            }
            return CinemaBackupEntry(path: "\(directoryName)/\(fileName)", data: data)
        }
    }

    private static func mergeProject(
        currentData: Data,
        backupData: Data,
        destinationURL: URL
    ) throws -> Bool {
        guard
            var current = jsonObject(from: currentData),
            let backup = jsonObject(from: backupData),
            let currentPath = current["filePath"] as? String,
            let backupPath = backup["filePath"] as? String,
            currentPath == backupPath
        else {
            return false
        }

        let currentAnalysis = current["analysisJSON"] as? String
        let backupAnalysis = backup["analysisJSON"] as? String
        guard
            (currentAnalysis == nil || currentAnalysis?.isEmpty == true),
            let backupAnalysis,
            !backupAnalysis.isEmpty
        else {
            return false
        }

        current["analysisJSON"] = backupAnalysis
        if let backupDuration = backup["duration"] as? NSNumber {
            let currentDuration = (current["duration"] as? NSNumber)?.doubleValue ?? 0
            if currentDuration <= 0 {
                current["duration"] = backupDuration
            }
        }
        let mergedData = try JSONSerialization.data(
            withJSONObject: current,
            options: [.sortedKeys]
        )
        try mergedData.write(to: destinationURL, options: .atomic)
        return true
    }

    private static func mergeArchive(
        indexPath: String,
        directoryName: String,
        backupEntries: [String: Data],
        supportDirectoryURL: URL,
        duplicateKey: ([String: Any]) -> String
    ) throws -> (added: Int, skipped: Int) {
        guard let backupIndexData = backupEntries[indexPath] else {
            return (0, 0)
        }

        let indexURL = supportDirectoryURL.appendingPathComponent(indexPath)
        var currentRecords = jsonArray(from: try? Data(contentsOf: indexURL))
        let backupRecords = jsonArray(from: backupIndexData)
        var knownKeys = Set(currentRecords.map(duplicateKey))
        var added = 0
        var skipped = 0
        let imageDirectoryURL = supportDirectoryURL.appendingPathComponent(
            directoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: imageDirectoryURL,
            withIntermediateDirectories: true
        )

        for var record in backupRecords {
            let key = duplicateKey(record)
            guard !key.isEmpty, !knownKeys.contains(key) else {
                skipped += 1
                continue
            }
            guard
                let originalFileName = safeFileName(record["imageFileName"] as? String),
                let imageData = backupEntries["\(directoryName)/\(originalFileName)"]
            else {
                throw CinemaBackupError.missingImage
            }

            var fileName = originalFileName
            var destinationURL = imageDirectoryURL.appendingPathComponent(fileName)
            if let existingData = try? Data(contentsOf: destinationURL), existingData != imageData {
                let fileExtension = destinationURL.pathExtension
                fileName = fileExtension.isEmpty
                    ? UUID().uuidString
                    : "\(UUID().uuidString).\(fileExtension)"
                destinationURL = imageDirectoryURL.appendingPathComponent(fileName)
                record["imageFileName"] = fileName
            }
            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                try imageData.write(to: destinationURL, options: .atomic)
            }
            currentRecords.append(record)
            knownKeys.insert(key)
            added += 1
        }

        if added > 0 {
            let data = try JSONSerialization.data(
                withJSONObject: currentRecords,
                options: [.sortedKeys]
            )
            try data.write(to: indexURL, options: .atomic)
        }
        return (added, skipped)
    }

    private static func mergeCollections(
        backupEntries: [String: Data],
        supportDirectoryURL: URL
    ) throws -> (added: Int, skipped: Int, idMap: [String: String]) {
        guard let backupData = backupEntries[collectionIndexPath] else {
            return (0, 0, [:])
        }

        let destinationURL = supportDirectoryURL.appendingPathComponent(collectionIndexPath)
        var currentRecords = jsonArray(from: try? Data(contentsOf: destinationURL))
        let backupRecords = jsonArray(from: backupData)
        var currentIds = Set(currentRecords.compactMap { $0["id"] as? String })
        var currentNames: [String: String] = [:]
        for record in currentRecords {
            guard
                let id = record["id"] as? String,
                let name = normalizedCollectionName(record["name"] as? String),
                !id.isEmpty,
                !name.isEmpty,
                currentNames[name] == nil
            else {
                continue
            }
            currentNames[name] = id
        }
        var idMap: [String: String] = [:]
        var added = 0
        var skipped = 0

        for record in backupRecords {
            guard
                let backupId = record["id"] as? String,
                !backupId.isEmpty,
                let name = normalizedCollectionName(record["name"] as? String),
                !name.isEmpty
            else {
                skipped += 1
                continue
            }
            if currentIds.contains(backupId) {
                idMap[backupId] = backupId
                skipped += 1
                continue
            }
            if let existingId = currentNames[name] {
                idMap[backupId] = existingId
                skipped += 1
                continue
            }
            currentRecords.append(record)
            currentIds.insert(backupId)
            currentNames[name] = backupId
            idMap[backupId] = backupId
            added += 1
        }

        if added > 0 {
            try jsonData(currentRecords).write(to: destinationURL, options: .atomic)
        }
        return (added, skipped, idMap)
    }

    private static func mergeMemberships(
        backupEntries: [String: Data],
        supportDirectoryURL: URL,
        collectionIdMap: [String: String]
    ) throws -> (added: Int, skipped: Int) {
        guard let backupData = backupEntries[membershipIndexPath] else {
            return (0, 0)
        }

        let destinationURL = supportDirectoryURL.appendingPathComponent(membershipIndexPath)
        var currentRecords = jsonArray(from: try? Data(contentsOf: destinationURL))
        let backupRecords = jsonArray(from: backupData)
        let validCollectionIds = Set(
            jsonArray(
                from: try? Data(
                    contentsOf: supportDirectoryURL.appendingPathComponent(collectionIndexPath)
                )
            ).compactMap { $0["id"] as? String }
        )
        let validFrameIds = Set(
            jsonArray(
                from: try? Data(
                    contentsOf: supportDirectoryURL.appendingPathComponent(frameIndexPath)
                )
            ).compactMap { $0["id"] as? String }
        )
        let validClipIds = Set(
            jsonArray(
                from: try? Data(
                    contentsOf: supportDirectoryURL.appendingPathComponent(clipIndexPath)
                )
            ).compactMap { $0["id"] as? String }
        )
        var knownKeys = Set(currentRecords.compactMap(membershipDuplicateKey))
        var knownIds = Set(currentRecords.compactMap { $0["id"] as? String })
        var added = 0
        var skipped = 0

        for var record in backupRecords {
            guard
                let backupCollectionId = record["collectionId"] as? String,
                let itemType = record["itemType"] as? String,
                let itemId = record["itemId"] as? String
            else {
                skipped += 1
                continue
            }
            let collectionId = collectionIdMap[backupCollectionId] ?? backupCollectionId
            let itemExists = itemType == "frame"
                ? validFrameIds.contains(itemId)
                : itemType == "clip" && validClipIds.contains(itemId)
            guard validCollectionIds.contains(collectionId), itemExists else {
                skipped += 1
                continue
            }

            record["collectionId"] = collectionId
            let key = "\(collectionId)|\(itemType)|\(itemId)"
            guard !knownKeys.contains(key) else {
                skipped += 1
                continue
            }
            let originalId = record["id"] as? String ?? ""
            if originalId.isEmpty || knownIds.contains(originalId) {
                record["id"] = UUID().uuidString
            }
            currentRecords.append(record)
            knownKeys.insert(key)
            knownIds.insert(record["id"] as? String ?? "")
            added += 1
        }

        if added > 0 {
            try jsonData(currentRecords).write(to: destinationURL, options: .atomic)
        }
        return (added, skipped)
    }

    private static func mergeNotes(
        backupEntries: [String: Data],
        supportDirectoryURL: URL,
        collectionIdMap: [String: String]
    ) throws -> (added: Int, skipped: Int) {
        guard let backupData = backupEntries[noteIndexPath] else {
            return (0, 0)
        }

        let destinationURL = supportDirectoryURL.appendingPathComponent(noteIndexPath)
        var currentRecords = jsonArray(from: try? Data(contentsOf: destinationURL))
        let backupRecords = jsonArray(from: backupData)
        let validCollectionIds = Set(
            jsonArray(
                from: try? Data(
                    contentsOf: supportDirectoryURL.appendingPathComponent(collectionIndexPath)
                )
            ).compactMap { $0["id"] as? String }
        )
        var knownIds = Set(currentRecords.compactMap { $0["id"] as? String })
        var added = 0
        var skipped = 0

        for var record in backupRecords {
            guard let id = record["id"] as? String, !id.isEmpty else {
                skipped += 1
                continue
            }
            guard !knownIds.contains(id) else {
                skipped += 1
                continue
            }
            let backupCollectionIds = record["collectionIds"] as? [String] ?? []
            var seenIds = Set<String>()
            let collectionIds = backupCollectionIds.compactMap { backupId -> String? in
                let destinationId = collectionIdMap[backupId] ?? backupId
                guard
                    validCollectionIds.contains(destinationId),
                    seenIds.insert(destinationId).inserted
                else {
                    return nil
                }
                return destinationId
            }
            guard !collectionIds.isEmpty else {
                skipped += 1
                continue
            }
            record["collectionIds"] = collectionIds
            currentRecords.append(record)
            knownIds.insert(id)
            added += 1
        }

        if added > 0 {
            try jsonData(currentRecords).write(to: destinationURL, options: .atomic)
        }
        return (added, skipped)
    }

    private static func membershipDuplicateKey(_ record: [String: Any]) -> String? {
        guard
            let collectionId = record["collectionId"] as? String,
            let itemType = record["itemType"] as? String,
            let itemId = record["itemId"] as? String,
            !collectionId.isEmpty,
            !itemType.isEmpty,
            !itemId.isEmpty
        else {
            return nil
        }
        return "\(collectionId)|\(itemType)|\(itemId)"
    }

    private static func normalizedCollectionName(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func frameDuplicateKey(_ record: [String: Any]) -> String {
        if let id = record["id"] as? String, !id.isEmpty {
            return "id:\(id)"
        }
        let source = record["sourceFilePath"] as? String ?? ""
        let shot = record["shotKey"] as? String ?? ""
        return source.isEmpty || shot.isEmpty ? "" : "frame:\(source)|\(shot)"
    }

    private static func clipDuplicateKey(_ record: [String: Any]) -> String {
        if let id = record["id"] as? String, !id.isEmpty {
            return "id:\(id)"
        }
        let source = record["sourceFilePath"] as? String ?? ""
        let start = (record["start"] as? NSNumber)?.doubleValue ?? -1
        let end = (record["end"] as? NSNumber)?.doubleValue ?? -1
        return source.isEmpty || start < 0 || end < 0
            ? ""
            : "clip:\(source)|\(Int((start * 100).rounded()))|\(Int((end * 100).rounded()))"
    }

    private static func shotCount(from projectData: Data?) -> Int {
        guard let projectData, let project = jsonObject(from: projectData) else {
            return 0
        }
        if
            let analysisText = project["analysisJSON"] as? String,
            let data = analysisText.data(using: .utf8),
            let analysis = jsonObject(from: data),
            let cutPoints = analysis["cutPoints"] as? [Any]
        {
            return max(0, cutPoints.count - 1)
        }
        if
            let analysis = project["analysis"] as? [String: Any],
            let cutPoints = analysis["cutPoints"] as? [Any]
        {
            return max(0, cutPoints.count - 1)
        }
        return 0
    }

    private static func entryData(
        _ path: String,
        in entries: [CinemaBackupEntry]
    ) -> Data? {
        entries.first(where: { $0.path == path })?.data
    }

    private static func sanitizedProjectBackupData(_ data: Data) -> Data {
        guard var project = jsonObject(from: data) else {
            return data
        }
        project.removeValue(forKey: "compatibleFilePath")
        return (try? jsonData(project)) ?? data
    }

    private static func jsonArray(from data: Data?) -> [[String: Any]] {
        guard
            let data,
            let value = try? JSONSerialization.jsonObject(with: data),
            let array = value as? [[String: Any]]
        else {
            return []
        }
        return array
    }

    private static func jsonObject(from data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func jsonData(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private static func safeFileName(_ value: String?) -> String? {
        guard let value else { return nil }
        let fileName = URL(fileURLWithPath: value).lastPathComponent
        return fileName == value ? fileName : nil
    }

    private static func isAllowedPath(_ path: String) -> Bool {
        if [
            projectPath,
            frameIndexPath,
            clipIndexPath,
            collectionIndexPath,
            membershipIndexPath,
            noteIndexPath,
        ].contains(path) {
            return true
        }
        guard !path.contains(".."), !path.hasPrefix("/") else {
            return false
        }
        let components = path.split(separator: "/")
        guard components.count == 2 else {
            return false
        }
        return components[0] == "archive-frames" || components[0] == "archive-clips"
    }
}
