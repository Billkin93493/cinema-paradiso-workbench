import Foundation

enum CinemaFramePackageExporterError: Error {
    case invalidPackage
    case noFrames
    case missingImage
    case destinationExists
    case zipFailed
}

enum CinemaFramePackageExporter {
    private struct Frame {
        let projectName: String
        let sourceFileName: String
        let shotNumber: Int
        let start: Double
        let end: Double
        let capturedAt: Double
        let imageURL: String
        let note: String
        let tags: [String]
    }

    static func export(
        package: [String: Any],
        destinationURL: URL,
        replaceExisting: Bool
    ) throws {
        guard
            let project = package["project"] as? [String: Any],
            let projectName = project["name"] as? String,
            let frameValues = package["frames"] as? [[String: Any]]
        else {
            throw CinemaFramePackageExporterError.invalidPackage
        }

        let frames = frameValues.compactMap { value -> Frame? in
            guard let imageURL = value["imageUrl"] as? String, !imageURL.isEmpty else {
                return nil
            }
            let sourcePath = value["sourceFilePath"] as? String ?? ""
            return Frame(
                projectName: value["projectName"] as? String ?? projectName,
                sourceFileName: URL(fileURLWithPath: sourcePath).lastPathComponent,
                shotNumber: number(value["shotNumber"]) ?? 1,
                start: decimal(value["start"]) ?? 0,
                end: decimal(value["end"]) ?? 0,
                capturedAt: decimal(value["capturedAt"]) ?? 0,
                imageURL: imageURL,
                note: value["note"] as? String ?? "",
                tags: value["tags"] as? [String] ?? []
            )
        }
        .sorted {
            if $0.shotNumber == $1.shotNumber {
                return $0.capturedAt < $1.capturedAt
            }
            return $0.shotNumber < $1.shotNumber
        }

        guard !frames.isEmpty else {
            throw CinemaFramePackageExporterError.noFrames
        }
        if FileManager.default.fileExists(atPath: destinationURL.path), !replaceExisting {
            throw CinemaFramePackageExporterError.destinationExists
        }

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("cinema-frames-\(UUID().uuidString)", isDirectory: true)
        let packageName = "\(safeFileName(projectName))-导演静帧资料包"
        let packageURL = temporaryRoot.appendingPathComponent(packageName, isDirectory: true)
        let framesURL = packageURL.appendingPathComponent("静帧", isDirectory: true)
        try FileManager.default.createDirectory(at: framesURL, withIntermediateDirectories: true)

        var indexRows = [[
            "文件名",
            "影片名称",
            "来源文件",
            "镜号",
            "收藏时间码",
            "镜头入点",
            "镜头出点",
            "标签",
            "导演笔记",
        ]]
        var usedFileNames = Set<String>()

        for frame in frames {
            guard let sourceURL = imageSourceURL(frame.imageURL) else {
                throw CinemaFramePackageExporterError.missingImage
            }
            let data = try Data(contentsOf: sourceURL)
            let imageExtension = imageExtension(for: data, sourceURL: sourceURL)
            let baseName = "镜\(String(format: "%03d", frame.shotNumber))_\(fileTimecode(frame.capturedAt))"
            let fileName = uniqueFileName(
                baseName: baseName,
                extensionName: imageExtension,
                usedFileNames: &usedFileNames
            )
            try data.write(to: framesURL.appendingPathComponent(fileName), options: .atomic)
            indexRows.append([
                fileName,
                frame.projectName,
                frame.sourceFileName,
                String(format: "%03d", frame.shotNumber),
                timecode(frame.capturedAt),
                timecode(frame.start),
                timecode(frame.end),
                frame.tags.joined(separator: " / "),
                frame.note,
            ])
        }

        let csv = "\u{FEFF}" + indexRows
            .map { $0.map(csvField).joined(separator: ",") }
            .joined(separator: "\r\n")
        try Data(csv.utf8).write(
            to: packageURL.appendingPathComponent("静帧索引.csv"),
            options: .atomic
        )

        let temporaryZipURL = temporaryRoot.appendingPathComponent("\(packageName).zip")
        try zipPackage(
            packageName: packageName,
            rootURL: temporaryRoot,
            destinationURL: temporaryZipURL
        )
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: temporaryZipURL)
        } else {
            try FileManager.default.moveItem(at: temporaryZipURL, to: destinationURL)
        }
    }

    static func safeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = value.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "未命名影片" : cleaned
    }

    private static func imageSourceURL(_ value: String) -> URL? {
        if value.hasPrefix("file://") {
            return URL(string: value)
        }
        if value.hasPrefix("/") {
            return URL(fileURLWithPath: value)
        }
        return nil
    }

    private static func imageExtension(for data: Data, sourceURL: URL) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            return "webp"
        }
        let sourceExtension = sourceURL.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp"].contains(sourceExtension)
            ? sourceExtension
            : "jpg"
    }

    private static func uniqueFileName(
        baseName: String,
        extensionName: String,
        usedFileNames: inout Set<String>
    ) -> String {
        var suffix = 1
        var candidate = "\(baseName).\(extensionName)"
        while usedFileNames.contains(candidate) {
            suffix += 1
            candidate = "\(baseName)-\(suffix).\(extensionName)"
        }
        usedFileNames.insert(candidate)
        return candidate
    }

    private static func timecode(_ seconds: Double) -> String {
        let safeSeconds = max(0, seconds)
        let hours = Int(safeSeconds / 3600)
        let minutes = Int(safeSeconds.truncatingRemainder(dividingBy: 3600) / 60)
        let wholeSeconds = Int(safeSeconds.truncatingRemainder(dividingBy: 60))
        let frames = min(24, Int(safeSeconds.truncatingRemainder(dividingBy: 1) * 25))
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, wholeSeconds, frames)
    }

    private static func fileTimecode(_ seconds: Double) -> String {
        timecode(seconds).replacingOccurrences(of: ":", with: "-")
    }

    private static func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func number(_ value: Any?) -> Int? {
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }

    private static func decimal(_ value: Any?) -> Double? {
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    private static func zipPackage(
        packageName: String,
        rootURL: URL,
        destinationURL: URL
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-qr", destinationURL.path, packageName]
        process.currentDirectoryURL = rootURL
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CinemaFramePackageExporterError.zipFailed
        }
    }
}
