import Cocoa
import AVFoundation
import WebKit
import UniformTypeIdentifiers

private let appName = "新天堂电影院·导演工作台"

private enum VideoCompatibilityError: LocalizedError {
    case protected(marker: String)
    case cannotCreateProxy
    case proxyExportFailed(String)
    case proxyStillUnreadable

    var errorDescription: String? {
        switch self {
        case .protected:
            return "这是受保护视频，软件不能读取画面。请换无保护的普通 MP4、MOV 或 MKV 文件。"
        case .cannotCreateProxy:
            return "当前影片格式太特殊，暂时无法自动生成兼容副本。请先导出为 1080p H.264/AAC MP4。"
        case .proxyExportFailed(let reason):
            return "兼容副本生成失败：\(reason)。请先导出为 1080p H.264/AAC MP4。"
        case .proxyStillUnreadable:
            return "兼容副本仍然无法读取画面。请先导出为 1080p H.264/AAC MP4。"
        }
    }
}

private struct ProjectRecord: Codable {
    var name: String
    var filePath: String
    var compatibleFilePath: String?
    var size: UInt64
    var duration: Double
    var updatedAt: String
    var category: String? = nil
    var analysisJSON: String?

    var bridgeValue: [String: Any] {
        let usableCompatibleFilePath = compatibleFilePath
            .flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
        let playbackPath = usableCompatibleFilePath ?? filePath
        var value: [String: Any] = [
            "name": name,
            "filePath": filePath,
            "fileUrl": URL(fileURLWithPath: playbackPath).absoluteString,
            "sourceFileUrl": URL(fileURLWithPath: filePath).absoluteString,
            "size": size,
            "duration": duration,
            "updatedAt": updatedAt,
            "usingCompatibleCopy": playbackPath != filePath,
        ]
        if let category, !category.isEmpty {
            value["category"] = category
        }
        if let compatibleFilePath = usableCompatibleFilePath {
            value["compatibleFilePath"] = compatibleFilePath
        }
        if
            let analysisJSON,
            let data = analysisJSON.data(using: .utf8),
            let analysis = try? JSONSerialization.jsonObject(with: data)
        {
            value["analysis"] = analysis
        }
        return value
    }
}

private struct ProjectCategoryRecord: Codable {
    var id: String
    var name: String
    var color: String
    var builtIn: Bool
    var createdAt: String
    var updatedAt: String

    var bridgeValue: [String: Any] {
        [
            "id": id,
            "name": name,
            "color": color,
            "builtIn": builtIn,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
        ]
    }
}

private struct ArchiveFrameRecord: Codable {
    var id: String
    var projectName: String
    var sourceFilePath: String
    var shotKey: String
    var shotNumber: Int
    var start: Double
    var end: Double
    var capturedAt: Double
    var imageFileName: String
    var note: String
    var tags: [String]
    var createdAt: String

    func bridgeValue(framesDirectoryURL: URL) -> [String: Any] {
        [
            "id": id,
            "projectName": projectName,
            "sourceFilePath": sourceFilePath,
            "sourceFileUrl": URL(fileURLWithPath: sourceFilePath).absoluteString,
            "shotKey": shotKey,
            "shotNumber": shotNumber,
            "start": start,
            "end": end,
            "capturedAt": capturedAt,
            "imageUrl": framesDirectoryURL.appendingPathComponent(imageFileName).absoluteString,
            "note": note,
            "tags": tags,
            "createdAt": createdAt,
        ]
    }
}

private struct ArchiveClipRecord: Codable {
    var id: String
    var projectName: String
    var sourceFilePath: String
    var shotKey: String
    var shotNumber: Int
    var start: Double
    var end: Double
    var capturedAt: Double
    var imageFileName: String
    var note: String
    var tags: [String]
    var createdAt: String

    func bridgeValue(clipsDirectoryURL: URL) -> [String: Any] {
        [
            "id": id,
            "type": "clip",
            "projectName": projectName,
            "sourceFilePath": sourceFilePath,
            "sourceFileUrl": URL(fileURLWithPath: sourceFilePath).absoluteString,
            "shotKey": shotKey,
            "shotNumber": shotNumber,
            "start": start,
            "end": end,
            "capturedAt": capturedAt,
            "imageUrl": clipsDirectoryURL.appendingPathComponent(imageFileName).absoluteString,
            "note": note,
            "tags": tags,
            "createdAt": createdAt,
        ]
    }
}

private struct InspirationCollectionRecord: Codable {
    var id: String
    var name: String
    var collectionDescription: String
    var createdAt: String
    var updatedAt: String
    var lastUsedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case collectionDescription = "description"
        case createdAt
        case updatedAt
        case lastUsedAt
    }

    var bridgeValue: [String: Any] {
        [
            "id": id,
            "name": name,
            "description": collectionDescription,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "lastUsedAt": lastUsedAt,
        ]
    }
}

private struct InspirationMembershipRecord: Codable {
    var id: String
    var collectionId: String
    var itemType: String
    var itemId: String
    var addedAt: String

    var bridgeValue: [String: Any] {
        [
            "id": id,
            "collectionId": collectionId,
            "itemType": itemType,
            "itemId": itemId,
            "addedAt": addedAt,
        ]
    }
}

private struct InspirationNoteRecord: Codable {
    var id: String
    var title: String
    var body: String
    var collectionIds: [String]
    var createdAt: String
    var updatedAt: String

    var bridgeValue: [String: Any] {
        [
            "id": id,
            "title": title,
            "body": body,
            "collectionIds": collectionIds,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
        ]
    }
}

private struct InspirationImageRecord: Codable {
    var id: String
    var title: String
    var imageFileName: String
    var note: String
    var collectionIds: [String]
    var createdAt: String
    var updatedAt: String

    func bridgeValue(imagesDirectoryURL: URL) -> [String: Any] {
        [
            "id": id,
            "title": title,
            "imageUrl": imagesDirectoryURL.appendingPathComponent(imageFileName).absoluteString,
            "note": note,
            "collectionIds": collectionIds,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
        ]
    }
}

final class DirectorWorkbenchApp: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    private var mainWindow: NSWindow!
    private var webView: WKWebView!
    private var childWindows: [NSWindow] = []
    private var hasStarted = false
    private var pendingRestoreBackupURL: URL?

    private var supportDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(appName, isDirectory: true)
    }

    private var projectFileURL: URL {
        supportDirectoryURL.appendingPathComponent("recent-project.json")
    }

    private var projectLibraryFileURL: URL {
        supportDirectoryURL.appendingPathComponent("projects.json")
    }

    private var projectCategoriesFileURL: URL {
        supportDirectoryURL.appendingPathComponent("project-categories.json")
    }

    private var archiveFileURL: URL {
        supportDirectoryURL.appendingPathComponent("archive-frames.json")
    }

    private var archiveFramesDirectoryURL: URL {
        supportDirectoryURL.appendingPathComponent("archive-frames", isDirectory: true)
    }

    private var archiveClipsFileURL: URL {
        supportDirectoryURL.appendingPathComponent("archive-clips.json")
    }

    private var archiveClipsDirectoryURL: URL {
        supportDirectoryURL.appendingPathComponent("archive-clips", isDirectory: true)
    }

    private var inspirationCollectionsFileURL: URL {
        supportDirectoryURL.appendingPathComponent("inspiration-collections.json")
    }

    private var inspirationMembershipsFileURL: URL {
        supportDirectoryURL.appendingPathComponent("inspiration-memberships.json")
    }

    private var inspirationNotesFileURL: URL {
        supportDirectoryURL.appendingPathComponent("inspiration-notes.json")
    }

    private var inspirationImagesFileURL: URL {
        supportDirectoryURL.appendingPathComponent("inspiration-images.json")
    }

    private var inspirationImagesDirectoryURL: URL {
        supportDirectoryURL.appendingPathComponent("inspiration-images", isDirectory: true)
    }

    private var compatibleVideosDirectoryURL: URL {
        supportDirectoryURL.appendingPathComponent("compatible-videos", isDirectory: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        startApplication()
    }

    func startApplication() {
        guard !hasStarted else { return }
        hasStarted = true
        NSApp.setActivationPolicy(.regular)
        configureMenu()
        createMainWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func configureMenu() {
        let menu = NSMenu()
        let appMenuItem = NSMenuItem()
        menu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于\(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出\(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = menu
    }

    private func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(self, name: "cinemaDesktop")
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: bridgeScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        return configuration
    }

    private func createMainWindow() {
        let styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView,
        ]

        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 920),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        mainWindow.title = appName
        mainWindow.titleVisibility = .hidden
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.backgroundColor = NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.065, alpha: 1)
        mainWindow.minSize = NSSize(width: 1180, height: 760)
        mainWindow.center()

        webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        mainWindow.contentView = webView

        guard let resources = Bundle.main.resourceURL else {
            fatalError("缺少软件资源")
        }
        let indexURL = resources.appendingPathComponent("preview/index.html")
        webView.loadFileURL(indexURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))

        mainWindow.makeKeyAndOrderFront(nil)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            let body = message.body as? [String: Any],
            let requestId = body["requestId"] as? String,
            let action = body["action"] as? String
        else {
            return
        }

        switch action {
        case "selectVideo":
            selectVideo(requestId: requestId)
        case "getRecentProject":
            resolve(requestId: requestId, value: readProject()?.bridgeValue)
        case "getProjectLibrary":
            resolve(
                requestId: requestId,
                value: readProjectLibrary().map(\.bridgeValue)
            )
        case "getProjectCategories":
            resolve(
                requestId: requestId,
                value: readProjectCategories().map(\.bridgeValue)
            )
        case "createProjectCategory":
            let payload = body["payload"] as? [String: Any]
            createProjectCategory(payload: payload, requestId: requestId)
        case "openProjectFromLibrary":
            let payload = body["payload"] as? [String: Any]
            openProjectFromLibrary(payload: payload, requestId: requestId)
        case "removeProjectFromLibrary":
            let payload = body["payload"] as? [String: Any]
            removeProjectFromLibrary(payload: payload, requestId: requestId)
        case "updateProjectCategory":
            let payload = body["payload"] as? [String: Any]
            updateProjectCategory(payload: payload, requestId: requestId)
        case "updateProject":
            let payload = body["payload"] as? [String: Any]
            let duration = payload?["duration"] as? Double ?? 0
            updateProject(duration: duration, requestId: requestId)
        case "saveAnalysis":
            let payload = body["payload"]
            saveAnalysis(payload: payload, requestId: requestId)
        case "getInspirationCollections":
            resolve(
                requestId: requestId,
                value: readInspirationCollections().map(\.bridgeValue)
            )
        case "createInspirationCollection":
            let payload = body["payload"] as? [String: Any]
            createInspirationCollection(payload: payload, requestId: requestId)
        case "updateInspirationCollection":
            let payload = body["payload"] as? [String: Any]
            updateInspirationCollection(payload: payload, requestId: requestId)
        case "deleteInspirationCollection":
            let payload = body["payload"] as? [String: Any]
            deleteInspirationCollection(payload: payload, requestId: requestId)
        case "touchInspirationCollection":
            let payload = body["payload"] as? [String: Any]
            touchInspirationCollection(payload: payload, requestId: requestId)
        case "getInspirationMemberships":
            resolve(
                requestId: requestId,
                value: readInspirationMemberships().map(\.bridgeValue)
            )
        case "addArchiveRecordToInspiration":
            let payload = body["payload"] as? [String: Any]
            addArchiveRecordToInspiration(payload: payload, requestId: requestId)
        case "removeArchiveFromInspiration":
            let payload = body["payload"] as? [String: Any]
            removeArchiveFromInspiration(payload: payload, requestId: requestId)
        case "getInspirationNotes":
            resolve(
                requestId: requestId,
                value: readInspirationNotes().map(\.bridgeValue)
            )
        case "upsertInspirationNote":
            let payload = body["payload"] as? [String: Any]
            upsertInspirationNote(payload: payload, requestId: requestId)
        case "getInspirationImages":
            resolve(
                requestId: requestId,
                value: readInspirationImages().map {
                    $0.bridgeValue(imagesDirectoryURL: inspirationImagesDirectoryURL)
                }
            )
        case "importInspirationImages":
            let payload = body["payload"] as? [String: Any]
            importInspirationImages(payload: payload, requestId: requestId)
        case "analyzeLocalVideo":
            analyzeLocalVideo(requestId: requestId)
        case "generateRepresentativeFrames":
            let payload = body["payload"] as? [String: Any]
            generateRepresentativeFrames(payload: payload, requestId: requestId)
        case "analyzeBasicScenes":
            let payload = body["payload"] as? [String: Any]
            analyzeBasicScenes(payload: payload, requestId: requestId)
        case "saveRepresentativeFrame":
            let payload = body["payload"] as? [String: Any]
            saveRepresentativeFrame(payload: payload, requestId: requestId)
        case "getArchiveFrames":
            resolve(
                requestId: requestId,
                value: readArchiveFrames().map {
                    $0.bridgeValue(framesDirectoryURL: archiveFramesDirectoryURL)
                }
            )
        case "saveArchiveFrame":
            let payload = body["payload"] as? [String: Any]
            saveArchiveFrame(payload: payload, requestId: requestId)
        case "updateArchiveTags":
            let payload = body["payload"] as? [String: Any]
            updateArchiveTags(payload: payload, requestId: requestId)
        case "updateArchiveNote":
            let payload = body["payload"] as? [String: Any]
            updateArchiveNote(payload: payload, requestId: requestId)
        case "syncArchiveShot":
            let payload = body["payload"] as? [String: Any]
            syncArchiveShot(payload: payload, requestId: requestId)
        case "syncArchiveRepresentativeFrame":
            let payload = body["payload"] as? [String: Any]
            syncArchiveRepresentativeFrame(payload: payload, requestId: requestId)
        case "openArchiveFrame":
            let payload = body["payload"] as? [String: Any]
            openArchiveFrame(payload: payload, requestId: requestId)
        case "getArchiveClips":
            resolve(
                requestId: requestId,
                value: readArchiveClips().map {
                    $0.bridgeValue(clipsDirectoryURL: archiveClipsDirectoryURL)
                }
            )
        case "saveArchiveClip":
            let payload = body["payload"] as? [String: Any]
            saveArchiveClip(payload: payload, requestId: requestId)
        case "openArchiveClip":
            let payload = body["payload"] as? [String: Any]
            openArchiveClip(payload: payload, requestId: requestId)
        case "relinkInspirationSource":
            let payload = body["payload"] as? [String: Any]
            relinkInspirationSource(payload: payload, requestId: requestId)
        case "exportExcel":
            let payload = body["payload"] as? [String: Any]
            exportExcel(payload: payload, requestId: requestId)
        case "exportFramePackage":
            let payload = body["payload"] as? [String: Any]
            exportFramePackage(payload: payload, requestId: requestId)
        case "createLocalBackup":
            createLocalBackup(requestId: requestId)
        case "selectRestoreBackup":
            selectRestoreBackup(requestId: requestId)
        case "restoreSelectedBackup":
            restoreSelectedBackup(requestId: requestId)
        case "getAITranslationSettings":
            resolve(
                requestId: requestId,
                value: ["configured": AITranslationCredentialStore.isConfigured]
            )
        case "saveAITranslationKey":
            let payload = body["payload"] as? [String: Any]
            saveAITranslationKey(payload: payload, requestId: requestId)
        case "removeAITranslationKey":
            removeAITranslationKey(requestId: requestId)
        case "translateSubtitles":
            let payload = body["payload"] as? [String: Any]
            translateSubtitles(payload: payload, requestId: requestId)
        case "getCloudSubtitleSettings":
            resolve(
                requestId: requestId,
                value: ["configured": CloudSubtitleCredentialStore.isConfigured]
            )
        case "saveCloudSubtitleKey":
            let payload = body["payload"] as? [String: Any]
            saveCloudSubtitleKey(payload: payload, requestId: requestId)
        case "removeCloudSubtitleKey":
            removeCloudSubtitleKey(requestId: requestId)
        case "extractCloudSubtitles":
            extractCloudSubtitles(requestId: requestId)
        case "readSubtitles":
            readSubtitles(requestId: requestId)
        default:
            resolve(requestId: requestId, value: nil)
        }
    }

    private func saveAITranslationKey(payload: [String: Any]?, requestId: String) {
        let key = (payload?["key"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard key.hasPrefix("sk-"), key.count >= 20 else {
            resolve(requestId: requestId, value: ["error": "这串密钥格式不正确，请重新检查"])
            return
        }
        do {
            try AITranslationCredentialStore.save(key: key)
            resolve(requestId: requestId, value: ["configured": true])
        } catch {
            resolve(requestId: requestId, value: ["error": "密钥没有保存成功，请重试"])
        }
    }

    private func removeAITranslationKey(requestId: String) {
        do {
            try AITranslationCredentialStore.remove()
            resolve(requestId: requestId, value: ["configured": false])
        } catch {
            resolve(requestId: requestId, value: ["error": "密钥没有移除成功，请重试"])
        }
    }

    private func translateSubtitles(payload: [String: Any]?, requestId: String) {
        guard let rawCues = payload?["cues"] as? [[String: Any]] else {
            resolve(requestId: requestId, value: ["error": "没有可翻译的英文字幕"])
            return
        }
        let cues = rawCues.compactMap { item -> SubtitleTranslationCue? in
            guard
                let id = (item["id"] as? NSNumber)?.intValue ?? item["id"] as? Int,
                let text = item["text"] as? String,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }
            return SubtitleTranslationCue(id: id, text: text)
        }
        guard !cues.isEmpty, cues.count <= 20_000 else {
            resolve(requestId: requestId, value: ["error": "英文字幕数量异常，请重新导入字幕"])
            return
        }
        let apiKey: String
        do {
            apiKey = try AITranslationCredentialStore.loadKey()
        } catch {
            resolve(requestId: requestId, value: ["error": "请先保存 DeepSeek 密钥"])
            return
        }

        Task { [weak self] in
            let result = await DeepSeekSubtitleTranslator().translate(
                cues: cues,
                apiKey: apiKey
            ) { translated, total in
                DispatchQueue.main.async {
                    self?.sendProgress(
                        requestId: requestId,
                        value: [
                            "translated": translated,
                            "total": total,
                            "percent": Int((Double(translated) / Double(max(1, total))) * 100),
                        ]
                    )
                }
            }
            DispatchQueue.main.async {
                self?.resolve(requestId: requestId, value: result.bridgeValue)
            }
        }
    }

    private func saveCloudSubtitleKey(payload: [String: Any]?, requestId: String) {
        let key = (payload?["key"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard key.hasPrefix("sk-"), key.count >= 20 else {
            resolve(requestId: requestId, value: ["error": "这串 OpenAI 密钥格式不正确，请重新检查"])
            return
        }
        do {
            try CloudSubtitleCredentialStore.save(key: key)
            resolve(requestId: requestId, value: ["configured": true])
        } catch {
            resolve(requestId: requestId, value: ["error": "OpenAI 密钥没有保存成功，请重试"])
        }
    }

    private func removeCloudSubtitleKey(requestId: String) {
        do {
            try CloudSubtitleCredentialStore.remove()
            resolve(requestId: requestId, value: ["configured": false])
        } catch {
            resolve(requestId: requestId, value: ["error": "OpenAI 密钥没有移除成功，请重试"])
        }
    }

    private func extractCloudSubtitles(requestId: String) {
        guard let project = readProject() else {
            resolve(requestId: requestId, value: ["error": "请先导入影片"])
            return
        }
        let apiKey: String
        do {
            apiKey = try CloudSubtitleCredentialStore.loadKey()
        } catch {
            resolve(requestId: requestId, value: ["error": "请先保存 OpenAI 密钥"])
            return
        }

        let videoURL = analysisVideoURL(for: project)
        Task { [weak self] in
            let result = await CloudSubtitleExtractor().extract(
                videoURL: videoURL,
                duration: project.duration,
                apiKey: apiKey
            ) { progress in
                DispatchQueue.main.async {
                    self?.sendProgress(
                        requestId: requestId,
                        value: progress.bridgeValue
                    )
                }
            }
            DispatchQueue.main.async {
                self?.resolve(requestId: requestId, value: result.bridgeValue)
            }
        }
    }

    private func readSubtitles(requestId: String) {
        guard let project = readProject() else {
            resolve(requestId: requestId, value: ["error": "请先导入影片"])
            return
        }
        let videoURL = URL(fileURLWithPath: project.filePath)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = ExistingSubtitleReader.read(videoURL: videoURL)
            DispatchQueue.main.async {
                self?.resolve(requestId: requestId, value: result.bridgeValue)
            }
        }
    }

    private func analysisVideoURL(for project: ProjectRecord) -> URL {
        if
            let compatibleFilePath = project.compatibleFilePath,
            FileManager.default.fileExists(atPath: compatibleFilePath)
        {
            return URL(fileURLWithPath: compatibleFilePath)
        }
        return URL(fileURLWithPath: project.filePath)
    }

    private func protectedVideoMarker(in url: URL) -> String? {
        let markers = ["drms", "encv", "enca", "cenc"]
        let markerData = markers.compactMap { marker in
            marker.data(using: .ascii).map { (marker, $0) }
        }
        guard
            let maxMarkerLength = markerData.map({ $0.1.count }).max(),
            let handle = try? FileHandle(forReadingFrom: url)
        else {
            return nil
        }
        defer {
            try? handle.close()
        }

        let chunkSize = 1024 * 1024
        let maxBytes = 128 * 1024 * 1024
        var scannedBytes = 0
        var carry = Data()

        while scannedBytes < maxBytes {
            let length = min(chunkSize, maxBytes - scannedBytes)
            let chunk = handle.readData(ofLength: length)
            if chunk.isEmpty { break }
            scannedBytes += chunk.count

            var searchData = carry
            searchData.append(chunk)
            for (marker, data) in markerData where searchData.range(of: data) != nil {
                return marker
            }

            let carryLength = max(0, maxMarkerLength - 1)
            carry = searchData.count > carryLength
                ? Data(searchData.suffix(carryLength))
                : searchData
        }
        return nil
    }

    private func canExtractVideoFrame(from url: URL) -> Bool {
        let asset = AVURLAsset(url: url)
        guard asset.tracks(withMediaType: .video).first != nil else {
            return false
        }

        let duration = asset.duration.seconds
        let sampleSecond: Double
        if duration.isFinite, duration > 2 {
            sampleSecond = min(duration - 0.5, max(1, duration / 2))
        } else {
            sampleSecond = 0.1
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)

        do {
            _ = try generator.copyCGImage(
                at: CMTime(seconds: sampleSecond, preferredTimescale: 600),
                actualTime: nil
            )
            return true
        } catch {
            return false
        }
    }

    private func ffmpegExecutableURL() -> URL? {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("ffmpeg"),
            URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/local/bin/ffmpeg"),
        ].compactMap { $0 }

        return candidates.first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }

    private func compatibleProxyURL(for sourceURL: URL) -> URL {
        let safeName = sourceURL.deletingPathExtension().lastPathComponent
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let baseName = safeName.isEmpty ? "video" : safeName
        return compatibleVideosDirectoryURL
            .appendingPathComponent("\(baseName)-\(UUID().uuidString).mp4")
    }

    private func createCompatibleVideoProxy(
        from sourceURL: URL,
        progress: @escaping (_ percent: Int, _ message: String) -> Void
    ) throws -> URL {
        try FileManager.default.createDirectory(
            at: compatibleVideosDirectoryURL,
            withIntermediateDirectories: true
        )
        let destinationURL = compatibleProxyURL(for: sourceURL)

        var usedFFmpeg = false
        if let ffmpegURL = ffmpegExecutableURL() {
            usedFFmpeg = true
            try transcodeWithFFmpeg(
                sourceURL: sourceURL,
                destinationURL: destinationURL,
                executableURL: ffmpegURL,
                progress: progress
            )
        } else {
            try exportCompatibleVideoWithAVFoundation(
                sourceURL: sourceURL,
                destinationURL: destinationURL,
                progress: progress
            )
        }

        guard
            FileManager.default.fileExists(atPath: destinationURL.path),
            ((try? destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 0
        else {
            throw VideoCompatibilityError.proxyStillUnreadable
        }

        guard usedFFmpeg || canExtractVideoFrame(from: destinationURL) else {
            throw VideoCompatibilityError.proxyStillUnreadable
        }
        return destinationURL
    }

    private func transcodeWithFFmpeg(
        sourceURL: URL,
        destinationURL: URL,
        executableURL: URL,
        progress: (_ percent: Int, _ message: String) -> Void
    ) throws {
        progress(12, "正在用兼容模式处理影片…")

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "-hide_banner",
            "-nostdin",
            "-nostats",
            "-loglevel", "error",
            "-y",
            "-i", sourceURL.path,
            "-vf", "scale=min(1920\\,iw):-2",
            "-r", "30",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-crf", "20",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "160k",
            "-movflags", "+faststart",
            destinationURL.path,
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            var seconds = 0
            while process.isRunning {
                Thread.sleep(forTimeInterval: 1)
                seconds += 1
                let percent = min(27, 12 + seconds / 10)
                progress(percent, "正在生成兼容副本，长片可能需要几分钟…")
            }
            process.waitUntilExit()
        } catch {
            throw VideoCompatibilityError.proxyExportFailed(error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let reason = String(data: data, encoding: .utf8)?
                .split(separator: "\n")
                .suffix(2)
                .joined(separator: " ")
            throw VideoCompatibilityError.proxyExportFailed(reason ?? "转换工具没有完成处理")
        }

        progress(28, "兼容副本已生成，正在检查画面…")
    }

    private func exportCompatibleVideoWithAVFoundation(
        sourceURL: URL,
        destinationURL: URL,
        progress: (_ percent: Int, _ message: String) -> Void
    ) throws {
        let asset = AVURLAsset(url: sourceURL)
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let preset = [
            AVAssetExportPreset1920x1080,
            AVAssetExportPreset1280x720,
            AVAssetExportPresetHighestQuality,
        ].first { compatiblePresets.contains($0) }

        guard
            let preset,
            let session = AVAssetExportSession(asset: asset, presetName: preset),
            session.supportedFileTypes.contains(.mp4)
        else {
            throw VideoCompatibilityError.cannotCreateProxy
        }

        session.outputURL = destinationURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        progress(8, "原片读取不稳定，正在生成兼容副本…")
        let semaphore = DispatchSemaphore(value: 0)
        session.exportAsynchronously {
            semaphore.signal()
        }

        while semaphore.wait(timeout: .now() + 0.5) == .timedOut {
            let percent = 8 + Int((session.progress * 20).rounded())
            progress(min(28, max(8, percent)), "正在生成兼容副本…")
        }

        guard session.status == .completed else {
            let reason = session.error?.localizedDescription ?? "系统转换没有完成"
            throw VideoCompatibilityError.proxyExportFailed(reason)
        }

        progress(28, "兼容副本已生成，正在检查画面…")
    }

    private func ensureReadableAnalysisVideo(
        for project: ProjectRecord,
        requestId: String
    ) throws -> (ProjectRecord, URL) {
        if
            let compatibleFilePath = project.compatibleFilePath,
            FileManager.default.fileExists(atPath: compatibleFilePath)
        {
            let compatibleURL = URL(fileURLWithPath: compatibleFilePath)
            if canExtractVideoFrame(from: compatibleURL) {
                return (project, compatibleURL)
            }
        }

        let sourceURL = URL(fileURLWithPath: project.filePath)
        if canExtractVideoFrame(from: sourceURL) {
            return (project, sourceURL)
        }

        if let marker = protectedVideoMarker(in: sourceURL) {
            throw VideoCompatibilityError.protected(marker: marker)
        }

        DispatchQueue.main.async {
            self.sendProgress(
                requestId: requestId,
                value: [
                    "phase": "compatibility",
                    "percent": 8,
                    "message": "原片读取不稳定，正在生成兼容副本…",
                ]
            )
        }

        let proxyURL = try createCompatibleVideoProxy(from: sourceURL) { percent, message in
            DispatchQueue.main.async {
                self.sendProgress(
                    requestId: requestId,
                    value: [
                        "phase": "compatibility",
                        "percent": percent,
                        "message": message,
                    ]
                )
            }
        }

        var updatedProject = project
        updatedProject.compatibleFilePath = proxyURL.path
        updatedProject.updatedAt = ISO8601DateFormatter().string(from: Date())
        writeProject(updatedProject)
        DispatchQueue.main.async {
            self.sendProgress(
                requestId: requestId,
                value: [
                    "phase": "compatibility",
                    "percent": 32,
                    "message": "兼容副本已生成，开始分析镜头…",
                ]
            )
        }
        return (updatedProject, proxyURL)
    }

    private func selectVideo(requestId: String) {
        let panel = NSOpenPanel()
        panel.title = "选择要拉片的影片"
        panel.prompt = "导入影片"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ["mp4", "mov", "m4v", "webm", "mkv", "avi"]
            .compactMap { UTType(filenameExtension: $0) }

        panel.beginSheetModal(for: mainWindow) { [weak self] response in
            guard let self else { return }
            guard response == .OK, let fileURL = panel.url else {
                self.resolve(requestId: requestId, value: nil)
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                if
                    !self.canExtractVideoFrame(from: fileURL),
                    let marker = self.protectedVideoMarker(in: fileURL)
                {
                    DispatchQueue.main.async {
                        self.resolve(
                            requestId: requestId,
                            value: [
                                "error": VideoCompatibilityError.protected(marker: marker).localizedDescription,
                                "code": "protected-video",
                            ]
                        )
                    }
                    return
                }

                let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                let project = ProjectRecord(
                    name: fileURL.deletingPathExtension().lastPathComponent,
                    filePath: fileURL.path,
                    compatibleFilePath: nil,
                    size: UInt64(values?.fileSize ?? 0),
                    duration: 0,
                    updatedAt: ISO8601DateFormatter().string(from: Date()),
                    analysisJSON: nil
                )
                DispatchQueue.main.async {
                    self.writeProject(project)
                    self.resolve(requestId: requestId, value: project.bridgeValue)
                }
            }
        }
    }

    private func readStoredProject() -> ProjectRecord? {
        guard
            let data = try? Data(contentsOf: projectFileURL),
            let project = try? JSONDecoder().decode(ProjectRecord.self, from: data)
        else {
            return nil
        }
        return project
    }

    private func readProject() -> ProjectRecord? {
        guard
            let project = readStoredProject(),
            FileManager.default.fileExists(atPath: project.filePath)
        else {
            return nil
        }
        return project
    }

    private func defaultProjectCategories() -> [ProjectCategoryRecord] {
        let createdAt = "2026-06-21T00:00:00Z"
        return [
            ProjectCategoryRecord(
                id: "feature",
                name: "剧情长片",
                color: "blue",
                builtIn: true,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            ProjectCategoryRecord(
                id: "ad",
                name: "广告参考",
                color: "violet",
                builtIn: true,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            ProjectCategoryRecord(
                id: "short",
                name: "短片研究",
                color: "cyan",
                builtIn: true,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
        ]
    }

    private func readStoredProjectCategories() -> [ProjectCategoryRecord] {
        guard
            let data = try? Data(contentsOf: projectCategoriesFileURL),
            let records = try? JSONDecoder().decode([ProjectCategoryRecord].self, from: data)
        else {
            return []
        }
        return records.filter { !$0.id.isEmpty && !$0.name.isEmpty }
    }

    private func readProjectCategories() -> [ProjectCategoryRecord] {
        var categories = defaultProjectCategories()
        for record in readStoredProjectCategories() {
            if categories.contains(where: { $0.id == record.id }) { continue }
            categories.append(record)
        }
        return categories
    }

    private func writeStoredProjectCategories(_ records: [ProjectCategoryRecord]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        let defaultIds = Set(defaultProjectCategories().map(\.id))
        let customRecords = records.filter { !defaultIds.contains($0.id) }
        let data = try JSONEncoder().encode(customRecords)
        try data.write(to: projectCategoriesFileURL, options: .atomic)
    }

    private func projectCategoryNameExists(_ name: String, in records: [ProjectCategoryRecord]) -> Bool {
        records.contains {
            $0.name.compare(
                name,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
    }

    private func readProjectLibrary() -> [ProjectRecord] {
        var records: [ProjectRecord] = []
        if
            let data = try? Data(contentsOf: projectLibraryFileURL),
            let decoded = try? JSONDecoder().decode([ProjectRecord].self, from: data)
        {
            records = decoded.filter {
                FileManager.default.fileExists(atPath: $0.filePath)
            }
        }
        if
            let recent = readStoredProject(),
            FileManager.default.fileExists(atPath: recent.filePath),
            !records.contains(where: { $0.filePath == recent.filePath })
        {
            records.append(recent)
        }
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func writeProjectLibrary(_ records: [ProjectRecord]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(records)
        try data.write(to: projectLibraryFileURL, options: .atomic)
    }

    private func upsertProjectInLibrary(_ project: ProjectRecord) {
        var records = readProjectLibrary()
        records.removeAll { $0.filePath == project.filePath }
        records.append(project)
        try? writeProjectLibrary(records)
    }

    private func writeProject(_ project: ProjectRecord) {
        try? FileManager.default.createDirectory(
            at: projectFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(project) else { return }
        try? data.write(to: projectFileURL, options: .atomic)
        upsertProjectInLibrary(project)
    }

    private func openProjectFromLibrary(payload: [String: Any]?, requestId: String) {
        guard
            let filePath = payload?["filePath"] as? String,
            let project = readProjectLibrary().first(where: { $0.filePath == filePath })
        else {
            resolve(requestId: requestId, value: ["error": "没有找到这部影片的拉片记录"])
            return
        }
        guard FileManager.default.fileExists(atPath: project.filePath) else {
            resolve(requestId: requestId, value: ["error": "原影片已经移动，请重新导入或恢复关联"])
            return
        }
        writeProject(project)
        resolve(requestId: requestId, value: project.bridgeValue)
    }

    private func removeProjectFromLibrary(payload: [String: Any]?, requestId: String) {
        guard let filePath = payload?["filePath"] as? String, !filePath.isEmpty else {
            resolve(requestId: requestId, value: ["error": "没有找到要移除的影片记录"])
            return
        }

        var records = readProjectLibrary()
        let currentProject = readStoredProject()
        let removedCurrent = currentProject?.filePath == filePath
        let beforeCount = records.count
        records.removeAll { $0.filePath == filePath }

        do {
            try writeProjectLibrary(records)
            if removedCurrent {
                try? FileManager.default.removeItem(at: projectFileURL)
            }
            resolve(
                requestId: requestId,
                value: [
                    "removed": beforeCount != records.count || removedCurrent,
                    "removedCurrent": removedCurrent,
                    "projects": readProjectLibrary().map(\.bridgeValue),
                ]
            )
        } catch {
            resolve(requestId: requestId, value: ["error": "影片库记录没有移除成功，请重试"])
        }
    }

    private func createProjectCategory(payload: [String: Any]?, requestId: String) {
        let name = (payload?["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else {
            resolve(requestId: requestId, value: ["error": "请先填写分类名称"])
            return
        }
        guard name.count <= 16 else {
            resolve(requestId: requestId, value: ["error": "分类名称最多 16 个字"])
            return
        }

        let categories = readProjectCategories()
        guard !projectCategoryNameExists(name, in: categories) else {
            resolve(requestId: requestId, value: ["error": "这个分类已经存在，换一个名字试试"])
            return
        }

        let colors = ["blue", "violet", "cyan"]
        let customCount = readStoredProjectCategories().count
        let now = ISO8601DateFormatter().string(from: Date())
        let category = ProjectCategoryRecord(
            id: "category-\(UUID().uuidString)",
            name: name,
            color: colors[customCount % colors.count],
            builtIn: false,
            createdAt: now,
            updatedAt: now
        )

        do {
            var records = readStoredProjectCategories()
            records.append(category)
            try writeStoredProjectCategories(records)
            resolve(
                requestId: requestId,
                value: [
                    "category": category.bridgeValue,
                    "categories": readProjectCategories().map(\.bridgeValue),
                ]
            )
        } catch {
            resolve(requestId: requestId, value: ["error": "分类没有保存成功，请重试"])
        }
    }

    private func updateProjectCategory(payload: [String: Any]?, requestId: String) {
        guard let filePath = payload?["filePath"] as? String, !filePath.isEmpty else {
            resolve(requestId: requestId, value: ["error": "没有找到要归类的影片"])
            return
        }
        let category = (payload?["category"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let categoryIds = Set(readProjectCategories().map(\.id))
        guard categoryIds.contains(category) else {
            resolve(requestId: requestId, value: ["error": "没有找到这个分类"])
            return
        }

        var records = readProjectLibrary()
        var updatedProject: ProjectRecord?
        if let index = records.firstIndex(where: { $0.filePath == filePath }) {
            records[index].category = category
            updatedProject = records[index]
        }

        if var currentProject = readStoredProject(), currentProject.filePath == filePath {
            currentProject.category = category
            writeProject(currentProject)
            updatedProject = currentProject
        } else if updatedProject != nil {
            do {
                try writeProjectLibrary(records)
            } catch {
                resolve(requestId: requestId, value: ["error": "影片分类没有保存成功，请重试"])
                return
            }
        }

        guard let updatedProject else {
            resolve(requestId: requestId, value: ["error": "没有找到这部影片的拉片记录"])
            return
        }

        resolve(
            requestId: requestId,
            value: [
                "project": updatedProject.bridgeValue,
                "projects": readProjectLibrary().map(\.bridgeValue),
            ]
        )
    }

    private func updateProject(duration: Double, requestId: String) {
        guard var project = readProject() else {
            resolve(requestId: requestId, value: nil)
            return
        }
        project.duration = duration
        project.updatedAt = ISO8601DateFormatter().string(from: Date())
        writeProject(project)
        resolve(requestId: requestId, value: project.bridgeValue)
    }

    private func saveAnalysis(payload: Any?, requestId: String) {
        guard var project = readProject(), let payload else {
            resolve(requestId: requestId, value: nil)
            return
        }
        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let analysisJSON = String(data: data, encoding: .utf8)
        else {
            resolve(requestId: requestId, value: nil)
            return
        }
        project.analysisJSON = analysisJSON
        project.updatedAt = ISO8601DateFormatter().string(from: Date())
        writeProject(project)
        resolve(requestId: requestId, value: project.bridgeValue)
    }

    private func readInspirationCollections() -> [InspirationCollectionRecord] {
        guard
            let data = try? Data(contentsOf: inspirationCollectionsFileURL),
            let records = try? JSONDecoder().decode([InspirationCollectionRecord].self, from: data)
        else {
            return []
        }
        return records.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    private func writeInspirationCollections(_ records: [InspirationCollectionRecord]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(records)
        try data.write(to: inspirationCollectionsFileURL, options: .atomic)
    }

    private func readInspirationMemberships() -> [InspirationMembershipRecord] {
        guard
            let data = try? Data(contentsOf: inspirationMembershipsFileURL),
            let records = try? JSONDecoder().decode([InspirationMembershipRecord].self, from: data)
        else {
            return []
        }
        return records.sorted { $0.addedAt > $1.addedAt }
    }

    private func writeInspirationMemberships(_ records: [InspirationMembershipRecord]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(records)
        try data.write(to: inspirationMembershipsFileURL, options: .atomic)
    }

    private func readInspirationNotes() -> [InspirationNoteRecord] {
        guard
            let data = try? Data(contentsOf: inspirationNotesFileURL),
            let records = try? JSONDecoder().decode([InspirationNoteRecord].self, from: data)
        else {
            return []
        }
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func writeInspirationNotes(_ records: [InspirationNoteRecord]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(records)
        try data.write(to: inspirationNotesFileURL, options: .atomic)
    }

    private func readInspirationImages() -> [InspirationImageRecord] {
        guard
            let data = try? Data(contentsOf: inspirationImagesFileURL),
            let records = try? JSONDecoder().decode([InspirationImageRecord].self, from: data)
        else {
            return []
        }
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func writeInspirationImages(_ records: [InspirationImageRecord]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(records)
        try data.write(to: inspirationImagesFileURL, options: .atomic)
    }

    private func collectionNameExists(
        _ name: String,
        in records: [InspirationCollectionRecord],
        ignoring ignoredId: String? = nil
    ) -> Bool {
        records.contains {
            $0.id != ignoredId
                && $0.name.compare(
                    name,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) == .orderedSame
        }
    }

    private func collectionInput(
        from payload: [String: Any]?
    ) -> (name: String, description: String)? {
        let name = (payload?["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let description = (payload?["description"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty, !description.isEmpty else { return nil }
        return (name, description)
    }

    private func createInspirationCollection(payload: [String: Any]?, requestId: String) {
        guard let input = collectionInput(from: payload) else {
            resolve(requestId: requestId, value: ["error": "请填写收藏夹名称和一句说明"])
            return
        }
        var records = readInspirationCollections()
        guard !collectionNameExists(input.name, in: records) else {
            resolve(requestId: requestId, value: ["error": "已经有同名收藏夹，请换一个名称"])
            return
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let record = InspirationCollectionRecord(
            id: UUID().uuidString,
            name: input.name,
            collectionDescription: input.description,
            createdAt: now,
            updatedAt: now,
            lastUsedAt: now
        )
        records.append(record)
        do {
            try writeInspirationCollections(records)
            resolve(requestId: requestId, value: record.bridgeValue)
        } catch {
            resolve(requestId: requestId, value: ["error": "收藏夹没有保存成功，请重试"])
        }
    }

    private func updateInspirationCollection(payload: [String: Any]?, requestId: String) {
        guard
            let id = payload?["id"] as? String,
            let input = collectionInput(from: payload)
        else {
            resolve(requestId: requestId, value: ["error": "请填写收藏夹名称和一句说明"])
            return
        }
        var records = readInspirationCollections()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            resolve(requestId: requestId, value: ["error": "没有找到这个收藏夹"])
            return
        }
        guard !collectionNameExists(input.name, in: records, ignoring: id) else {
            resolve(requestId: requestId, value: ["error": "已经有同名收藏夹，请换一个名称"])
            return
        }
        let now = ISO8601DateFormatter().string(from: Date())
        records[index].name = input.name
        records[index].collectionDescription = input.description
        records[index].updatedAt = now
        records[index].lastUsedAt = now
        do {
            try writeInspirationCollections(records)
            resolve(requestId: requestId, value: records[index].bridgeValue)
        } catch {
            resolve(requestId: requestId, value: ["error": "收藏夹修改没有保存成功，请重试"])
        }
    }

    private func deleteInspirationCollection(payload: [String: Any]?, requestId: String) {
        guard let id = payload?["id"] as? String else {
            resolve(requestId: requestId, value: ["error": "没有找到这个收藏夹"])
            return
        }
        var records = readInspirationCollections()
        guard records.contains(where: { $0.id == id }) else {
            resolve(requestId: requestId, value: ["error": "没有找到这个收藏夹"])
            return
        }
        records.removeAll { $0.id == id }
        do {
            try writeInspirationCollections(records)
            let memberships = readInspirationMemberships().filter { $0.collectionId != id }
            try writeInspirationMemberships(memberships)
            let notes = readInspirationNotes().compactMap { note -> InspirationNoteRecord? in
                var updatedNote = note
                updatedNote.collectionIds.removeAll { $0 == id }
                return updatedNote.collectionIds.isEmpty ? nil : updatedNote
            }
            try writeInspirationNotes(notes)
            resolve(requestId: requestId, value: ["deleted": true, "id": id])
        } catch {
            resolve(requestId: requestId, value: ["error": "收藏夹没有删除成功，请重试"])
        }
    }

    private func addArchiveRecordToInspiration(
        payload: [String: Any]?,
        requestId: String
    ) {
        guard
            let collectionId = payload?["collectionId"] as? String,
            let itemType = payload?["itemType"] as? String,
            let itemId = payload?["itemId"] as? String,
            ["frame", "clip"].contains(itemType),
            !itemId.isEmpty
        else {
            resolve(requestId: requestId, value: ["error": "这份资料暂时不能加入收藏夹"])
            return
        }

        var collections = readInspirationCollections()
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionId }) else {
            resolve(requestId: requestId, value: ["error": "没有找到这个收藏夹"])
            return
        }
        let archiveExists = itemType == "frame"
            ? readArchiveFrames().contains(where: { $0.id == itemId })
            : readArchiveClips().contains(where: { $0.id == itemId })
        guard archiveExists else {
            resolve(requestId: requestId, value: ["error": "这份资料已经不在导演资料库中"])
            return
        }

        var memberships = readInspirationMemberships()
        if let existing = memberships.first(where: {
            $0.collectionId == collectionId
                && $0.itemType == itemType
                && $0.itemId == itemId
        }) {
            var value = existing.bridgeValue
            value["alreadyExists"] = true
            resolve(requestId: requestId, value: value)
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let record = InspirationMembershipRecord(
            id: UUID().uuidString,
            collectionId: collectionId,
            itemType: itemType,
            itemId: itemId,
            addedAt: now
        )
        memberships.append(record)
        collections[collectionIndex].lastUsedAt = now
        do {
            try writeInspirationMemberships(memberships)
            try writeInspirationCollections(collections)
            resolve(requestId: requestId, value: record.bridgeValue)
        } catch {
            resolve(requestId: requestId, value: ["error": "资料没有加入收藏夹，请重试"])
        }
    }

    private func removeArchiveFromInspiration(
        payload: [String: Any]?,
        requestId: String
    ) {
        guard
            let collectionId = payload?["collectionId"] as? String,
            let itemType = payload?["itemType"] as? String,
            let itemId = payload?["itemId"] as? String,
            !collectionId.isEmpty,
            ["frame", "clip"].contains(itemType),
            !itemId.isEmpty
        else {
            resolve(requestId: requestId, value: ["error": "这份资料暂时不能移出收藏夹"])
            return
        }

        let memberships = readInspirationMemberships()
        let remaining = memberships.filter {
            !(
                $0.collectionId == collectionId
                    && $0.itemType == itemType
                    && $0.itemId == itemId
            )
        }
        do {
            try writeInspirationMemberships(remaining)
            resolve(
                requestId: requestId,
                value: [
                    "removed": memberships.count - remaining.count,
                    "collectionId": collectionId,
                ]
            )
        } catch {
            resolve(requestId: requestId, value: ["error": "没有移出成功，请重试"])
        }
    }

    private func touchInspirationCollection(payload: [String: Any]?, requestId: String) {
        guard let id = payload?["id"] as? String else {
            resolve(requestId: requestId, value: nil)
            return
        }
        var records = readInspirationCollections()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            resolve(requestId: requestId, value: nil)
            return
        }
        records[index].lastUsedAt = ISO8601DateFormatter().string(from: Date())
        do {
            try writeInspirationCollections(records)
            resolve(requestId: requestId, value: records[index].bridgeValue)
        } catch {
            resolve(requestId: requestId, value: nil)
        }
    }

    private func upsertInspirationNote(payload: [String: Any]?, requestId: String) {
        let rawTitle = (payload?["title"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = (payload?["body"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawTitle.isEmpty || !body.isEmpty else {
            resolve(requestId: requestId, value: ["error": "请写下标题或正文"])
            return
        }

        var collections = readInspirationCollections()
        let availableCollectionIds = Set(collections.map(\.id))
        let requestedCollectionIds = payload?["collectionIds"] as? [String] ?? []
        var seenCollectionIds = Set<String>()
        let collectionIds = requestedCollectionIds.filter {
            availableCollectionIds.contains($0) && seenCollectionIds.insert($0).inserted
        }
        guard !collectionIds.isEmpty else {
            resolve(requestId: requestId, value: ["error": "请至少选择一个收藏夹"])
            return
        }

        var records = readInspirationNotes()
        let requestedId = payload?["id"] as? String
        let index = requestedId.flatMap { id in
            records.firstIndex(where: { $0.id == id })
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let record = InspirationNoteRecord(
            id: index.map { records[$0].id } ?? UUID().uuidString,
            title: rawTitle.isEmpty ? "未命名文字" : rawTitle,
            body: body,
            collectionIds: collectionIds,
            createdAt: index.map { records[$0].createdAt } ?? now,
            updatedAt: now
        )
        if let index {
            records[index] = record
        } else {
            records.append(record)
        }
        for collectionId in collectionIds {
            if let collectionIndex = collections.firstIndex(where: { $0.id == collectionId }) {
                collections[collectionIndex].lastUsedAt = now
            }
        }
        do {
            try writeInspirationNotes(records)
            try writeInspirationCollections(collections)
            resolve(requestId: requestId, value: record.bridgeValue)
        } catch {
            resolve(requestId: requestId, value: ["error": "文字卡片没有保存成功，请重试"])
        }
    }

    private func importInspirationImages(payload: [String: Any]?, requestId: String) {
        let collectionId = payload?["collectionId"] as? String ?? ""
        var collections = readInspirationCollections()
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionId }) else {
            resolve(requestId: requestId, value: ["error": "请先选择一个收藏夹"])
            return
        }

        let panel = NSOpenPanel()
        panel.title = "导入灵感图片"
        panel.prompt = "导入图片"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            .jpeg,
            .png,
            .webP,
            UTType(filenameExtension: "heic"),
            UTType(filenameExtension: "jpg"),
        ].compactMap { $0 }

        panel.beginSheetModal(for: mainWindow) { [weak self] response in
            guard let self else { return }
            guard response == .OK, !panel.urls.isEmpty else {
                self.resolve(requestId: requestId, value: ["cancelled": true])
                return
            }

            do {
                try FileManager.default.createDirectory(
                    at: self.inspirationImagesDirectoryURL,
                    withIntermediateDirectories: true
                )
                var records = self.readInspirationImages()
                let now = ISO8601DateFormatter().string(from: Date())
                var imported: [InspirationImageRecord] = []

                for sourceURL in panel.urls {
                    let id = UUID().uuidString
                    let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension.lowercased()
                    let fileName = "\(id).\(ext)"
                    let destinationURL = self.inspirationImagesDirectoryURL.appendingPathComponent(fileName)
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    let title = sourceURL.deletingPathExtension().lastPathComponent
                    let record = InspirationImageRecord(
                        id: id,
                        title: title.isEmpty ? "导入图片" : title,
                        imageFileName: fileName,
                        note: "",
                        collectionIds: [collectionId],
                        createdAt: now,
                        updatedAt: now
                    )
                    records.append(record)
                    imported.append(record)
                }

                collections[collectionIndex].lastUsedAt = now
                try self.writeInspirationImages(records)
                try self.writeInspirationCollections(collections)
                self.resolve(
                    requestId: requestId,
                    value: [
                        "importedCount": imported.count,
                        "images": records
                            .sorted { $0.updatedAt > $1.updatedAt }
                            .map {
                                $0.bridgeValue(imagesDirectoryURL: self.inspirationImagesDirectoryURL)
                            },
                    ]
                )
            } catch {
                self.resolve(requestId: requestId, value: ["error": "图片没有导入成功，请重试"])
            }
        }
    }

    private func exportExcel(payload: [String: Any]?, requestId: String) {
        guard
            let payload,
            let project = payload["project"] as? [String: Any],
            let projectName = project["name"] as? String,
            payload["shots"] is [[String: Any]]
        else {
            resolve(requestId: requestId, value: ["error": "当前拉片资料还不能导出"])
            return
        }

        let panel = NSSavePanel()
        panel.title = "保存专业图文拉片表"
        panel.prompt = "保存 Excel"
        panel.nameFieldStringValue = "\(CinemaExcelExporter.safeFileName(projectName))-专业图文拉片表.xlsx"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
        panel.canCreateDirectories = true

        panel.beginSheetModal(for: mainWindow) { [weak self] response in
            guard let self else { return }
            guard response == .OK, let destinationURL = panel.url else {
                self.resolve(requestId: requestId, value: ["cancelled": true])
                return
            }
            do {
                try CinemaExcelExporter.export(
                    report: payload,
                    destinationURL: destinationURL,
                    replaceExisting: true
                )
                self.resolve(
                    requestId: requestId,
                    value: [
                        "fileName": destinationURL.lastPathComponent,
                        "filePath": destinationURL.path,
                    ]
                )
            } catch {
                self.resolve(requestId: requestId, value: ["error": "Excel 没有保存成功，请重试"])
            }
        }
    }

    private func exportFramePackage(payload: [String: Any]?, requestId: String) {
        guard
            let payload,
            let project = payload["project"] as? [String: Any],
            let projectName = project["name"] as? String,
            let frames = payload["frames"] as? [[String: Any]],
            !frames.isEmpty
        else {
            resolve(requestId: requestId, value: ["error": "当前影片还没有收藏静帧"])
            return
        }

        let panel = NSSavePanel()
        panel.title = "保存导演静帧资料包"
        panel.prompt = "保存静帧包"
        panel.nameFieldStringValue = "\(CinemaFramePackageExporter.safeFileName(projectName))-导演静帧资料包.zip"
        panel.allowedContentTypes = [UTType.zip]
        panel.canCreateDirectories = true

        panel.beginSheetModal(for: mainWindow) { [weak self] response in
            guard let self else { return }
            guard response == .OK, let destinationURL = panel.url else {
                self.resolve(requestId: requestId, value: ["cancelled": true])
                return
            }
            do {
                try CinemaFramePackageExporter.export(
                    package: payload,
                    destinationURL: destinationURL,
                    replaceExisting: true
                )
                self.resolve(
                    requestId: requestId,
                    value: [
                        "fileName": destinationURL.lastPathComponent,
                        "filePath": destinationURL.path,
                        "frameCount": frames.count,
                    ]
                )
            } catch CinemaFramePackageExporterError.missingImage {
                self.resolve(requestId: requestId, value: ["error": "部分静帧文件已经移动或损坏"])
            } catch {
                self.resolve(requestId: requestId, value: ["error": "静帧资料包没有保存成功，请重试"])
            }
        }
    }

    private func createLocalBackup(requestId: String) {
        let panel = NSSavePanel()
        panel.title = "保存导演资料备份"
        panel.prompt = "创建备份"
        panel.nameFieldStringValue = "新天堂电影院-导演资料备份.cpbak"
        panel.allowedContentTypes = [
            UTType(exportedAs: "com.cinemaparadiso.directorworkbench.backup", conformingTo: .data)
        ]
        panel.canCreateDirectories = true

        panel.beginSheetModal(for: mainWindow) { [weak self] response in
            guard let self else { return }
            guard response == .OK, let destinationURL = panel.url else {
                self.resolve(requestId: requestId, value: ["cancelled": true])
                return
            }
            do {
                let summary = try CinemaBackupManager.createBackup(
                    supportDirectoryURL: self.supportDirectoryURL,
                    destinationURL: destinationURL
                )
                var value = summary.bridgeValue
                value["fileName"] = destinationURL.lastPathComponent
                value["filePath"] = destinationURL.path
                self.resolve(requestId: requestId, value: value)
            } catch CinemaBackupError.empty {
                self.resolve(requestId: requestId, value: ["error": "还没有可以备份的导演资料"])
            } catch CinemaBackupError.missingImage {
                self.resolve(requestId: requestId, value: ["error": "部分静帧或片段封面已经移动或损坏"])
            } catch {
                self.resolve(requestId: requestId, value: ["error": "备份文件没有保存成功，请重试"])
            }
        }
    }

    private func selectRestoreBackup(requestId: String) {
        let panel = NSOpenPanel()
        panel.title = "选择导演资料备份"
        panel.prompt = "查看备份"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(exportedAs: "com.cinemaparadiso.directorworkbench.backup", conformingTo: .data)
        ]

        panel.beginSheetModal(for: mainWindow) { [weak self] response in
            guard let self else { return }
            guard response == .OK, let backupURL = panel.url else {
                self.resolve(requestId: requestId, value: ["cancelled": true])
                return
            }
            do {
                let summary = try CinemaBackupManager.inspectBackup(at: backupURL)
                self.pendingRestoreBackupURL = backupURL
                var value = summary.bridgeValue
                value["fileName"] = backupURL.lastPathComponent
                value["filePath"] = backupURL.path
                self.resolve(requestId: requestId, value: value)
            } catch CinemaBackupError.unsupported {
                self.resolve(requestId: requestId, value: ["error": "这份备份来自暂不支持的软件版本"])
            } catch {
                self.resolve(requestId: requestId, value: ["error": "这不是有效的导演资料备份文件"])
            }
        }
    }

    private func restoreSelectedBackup(requestId: String) {
        guard let backupURL = pendingRestoreBackupURL else {
            resolve(requestId: requestId, value: ["error": "请先选择一份备份文件"])
            return
        }
        do {
            let result = try CinemaBackupManager.restoreBackup(
                from: backupURL,
                supportDirectoryURL: supportDirectoryURL
            )
            pendingRestoreBackupURL = nil
            resolve(requestId: requestId, value: result.bridgeValue)
        } catch CinemaBackupError.missingImage {
            resolve(requestId: requestId, value: ["error": "备份中的部分静帧或片段封面不完整"])
        } catch {
            resolve(requestId: requestId, value: ["error": "资料没有恢复成功，现有资料没有被删除"])
        }
    }

    private func readArchiveFrames() -> [ArchiveFrameRecord] {
        guard
            let data = try? Data(contentsOf: archiveFileURL),
            let records = try? JSONDecoder().decode([ArchiveFrameRecord].self, from: data)
        else {
            return []
        }
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    private func writeArchiveFrames(_ records: [ArchiveFrameRecord]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(records)
        try data.write(to: archiveFileURL, options: .atomic)
    }

    private func normalizedArchiveTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { value in
            let tag = String(value.prefix(20))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let key = tag.lowercased()
            guard !tag.isEmpty, !seen.contains(key) else { return nil }
            seen.insert(key)
            return tag
        }
        .prefix(20)
        .map { $0 }
    }

    private func restoredShotData(tags: [String], note: String) -> [String: Any] {
        let sizes = Set(["大远景", "远景", "全景", "中景", "近景", "特写", "大特写"])
        let angles = Set(["平视", "俯拍", "仰拍", "顶拍", "侧面", "主观"])
        let movements = Set(["固定", "推镜", "拉镜", "摇镜", "移镜", "跟拍", "升降", "手持"])
        return [
            "size": tags.first(where: sizes.contains) ?? "中景",
            "angle": tags.first(where: angles.contains) ?? "平视",
            "movement": tags.first(where: movements.contains) ?? "固定",
            "note": note,
        ]
    }

    private func updateArchiveTags(payload: [String: Any]?, requestId: String) {
        guard
            let payload,
            let items = payload["items"] as? [[String: Any]],
            let mode = payload["mode"] as? String,
            ["replace", "add", "remove"].contains(mode),
            !items.isEmpty
        else {
            resolve(requestId: requestId, value: ["error": "没有找到需要整理的资料"])
            return
        }

        let tags = normalizedArchiveTags(payload["tags"] as? [String] ?? [])
        if mode != "replace" && tags.isEmpty {
            resolve(requestId: requestId, value: ["error": "请先填写标签"])
            return
        }

        let frameIds = Set(items.compactMap { item -> String? in
            guard item["type"] as? String == "frame" else { return nil }
            return item["id"] as? String
        })
        let clipIds = Set(items.compactMap { item -> String? in
            guard item["type"] as? String == "clip" else { return nil }
            return item["id"] as? String
        })
        guard !frameIds.isEmpty || !clipIds.isEmpty else {
            resolve(requestId: requestId, value: ["error": "没有找到需要整理的资料"])
            return
        }

        func updatedTags(_ current: [String]) -> [String] {
            switch mode {
            case "replace":
                return tags
            case "remove":
                let removing = Set(tags.map { $0.lowercased() })
                return normalizedArchiveTags(current).filter {
                    !removing.contains($0.lowercased())
                }
            default:
                return normalizedArchiveTags(current + tags)
            }
        }

        var frames = readArchiveFrames()
        var clips = readArchiveClips()
        var changedFrames = false
        var changedClips = false

        for index in frames.indices where frameIds.contains(frames[index].id) {
            frames[index].tags = updatedTags(frames[index].tags)
            changedFrames = true
        }
        for index in clips.indices where clipIds.contains(clips[index].id) {
            clips[index].tags = updatedTags(clips[index].tags)
            changedClips = true
        }

        do {
            if changedFrames { try writeArchiveFrames(frames) }
            if changedClips { try writeArchiveClips(clips) }
            resolve(
                requestId: requestId,
                value: [
                    "frames": frames.map {
                        $0.bridgeValue(framesDirectoryURL: archiveFramesDirectoryURL)
                    },
                    "clips": clips.map {
                        $0.bridgeValue(clipsDirectoryURL: archiveClipsDirectoryURL)
                    },
                ]
            )
        } catch {
            resolve(requestId: requestId, value: ["error": "标签没有保存成功，请重试"])
        }
    }

    private func updateArchiveNote(payload: [String: Any]?, requestId: String) {
        guard
            let payload,
            let itemType = payload["itemType"] as? String,
            let itemId = payload["itemId"] as? String,
            ["frame", "clip"].contains(itemType),
            !itemId.isEmpty
        else {
            resolve(requestId: requestId, value: ["error": "这份资料暂时不能修改笔记"])
            return
        }

        let note = payload["note"] as? String ?? ""
        var frames = readArchiveFrames()
        var clips = readArchiveClips()
        var changed = false

        if itemType == "frame" {
            for index in frames.indices where frames[index].id == itemId {
                frames[index].note = note
                changed = true
            }
        } else {
            for index in clips.indices where clips[index].id == itemId {
                clips[index].note = note
                changed = true
            }
        }

        guard changed else {
            resolve(requestId: requestId, value: ["error": "这份资料已经不在导演资料库中"])
            return
        }

        do {
            if itemType == "frame" {
                try writeArchiveFrames(frames)
            } else {
                try writeArchiveClips(clips)
            }
            resolve(
                requestId: requestId,
                value: [
                    "frames": frames.map {
                        $0.bridgeValue(framesDirectoryURL: archiveFramesDirectoryURL)
                    },
                    "clips": clips.map {
                        $0.bridgeValue(clipsDirectoryURL: archiveClipsDirectoryURL)
                    },
                ]
            )
        } catch {
            resolve(requestId: requestId, value: ["error": "导演笔记没有保存成功，请重试"])
        }
    }

    private func syncArchiveShot(payload: [String: Any]?, requestId: String) {
        guard
            let sourceFilePath = payload?["sourceFilePath"] as? String,
            let shotKey = payload?["shotKey"] as? String,
            !sourceFilePath.isEmpty,
            !shotKey.isEmpty
        else {
            resolve(requestId: requestId, value: ["error": "没有找到需要同步的镜头资料"])
            return
        }

        let note = payload?["note"] as? String ?? ""
        let tags = normalizedArchiveTags(payload?["tags"] as? [String] ?? [])
        var frames = readArchiveFrames()
        var clips = readArchiveClips()
        var changedFrames = false
        var changedClips = false

        for index in frames.indices where frames[index].sourceFilePath == sourceFilePath && frames[index].shotKey == shotKey {
            frames[index].note = note
            frames[index].tags = tags
            changedFrames = true
        }

        for index in clips.indices where clips[index].sourceFilePath == sourceFilePath && clips[index].shotKey == shotKey {
            clips[index].note = note
            clips[index].tags = tags
            changedClips = true
        }

        do {
            if changedFrames { try writeArchiveFrames(frames) }
            if changedClips { try writeArchiveClips(clips) }
            resolve(
                requestId: requestId,
                value: [
                    "frames": frames.map {
                        $0.bridgeValue(framesDirectoryURL: archiveFramesDirectoryURL)
                    },
                    "clips": clips.map {
                        $0.bridgeValue(clipsDirectoryURL: archiveClipsDirectoryURL)
                    },
                ]
            )
        } catch {
            resolve(requestId: requestId, value: ["error": "资料库同步没有保存成功，请重试"])
        }
    }

    private func syncArchiveRepresentativeFrame(payload: [String: Any]?, requestId: String) {
        guard
            let sourceFilePath = payload?["sourceFilePath"] as? String,
            let shotKey = payload?["shotKey"] as? String,
            let imageDataURL = payload?["imageDataUrl"] as? String,
            !sourceFilePath.isEmpty,
            !shotKey.isEmpty,
            let encodedImage = imageDataURL.split(separator: ",", maxSplits: 1).last,
            let imageData = Data(base64Encoded: String(encodedImage))
        else {
            resolve(requestId: requestId, value: ["error": "代表静帧同步没有保存成功，请重试"])
            return
        }

        let capturedAt = (payload?["capturedAt"] as? NSNumber)?.doubleValue
        var frames = readArchiveFrames()
        var clips = readArchiveClips()
        var changedFrames = false
        var changedClips = false

        do {
            try FileManager.default.createDirectory(
                at: archiveFramesDirectoryURL,
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: archiveClipsDirectoryURL,
                withIntermediateDirectories: true
            )

            for index in frames.indices where frames[index].sourceFilePath == sourceFilePath && frames[index].shotKey == shotKey {
                try imageData.write(
                    to: archiveFramesDirectoryURL.appendingPathComponent(frames[index].imageFileName),
                    options: .atomic
                )
                if let capturedAt {
                    frames[index].capturedAt = capturedAt
                }
                changedFrames = true
            }

            for index in clips.indices where clips[index].sourceFilePath == sourceFilePath && clips[index].shotKey == shotKey {
                try imageData.write(
                    to: archiveClipsDirectoryURL.appendingPathComponent(clips[index].imageFileName),
                    options: .atomic
                )
                if let capturedAt {
                    clips[index].capturedAt = capturedAt
                }
                changedClips = true
            }

            if changedFrames { try writeArchiveFrames(frames) }
            if changedClips { try writeArchiveClips(clips) }
            resolve(
                requestId: requestId,
                value: [
                    "frames": frames.map {
                        $0.bridgeValue(framesDirectoryURL: archiveFramesDirectoryURL)
                    },
                    "clips": clips.map {
                        $0.bridgeValue(clipsDirectoryURL: archiveClipsDirectoryURL)
                    },
                ]
            )
        } catch {
            resolve(requestId: requestId, value: ["error": "代表静帧同步没有保存成功，请重试"])
        }
    }

    private func saveArchiveFrame(payload: [String: Any]?, requestId: String) {
        guard
            let project = readProject(),
            let payload,
            let shotKey = payload["shotKey"] as? String,
            let imageDataURL = payload["imageDataUrl"] as? String
        else {
            resolve(requestId: requestId, value: ["error": "当前镜头还不能收藏"])
            return
        }

        var records = readArchiveFrames()
        if let existing = records.first(where: {
            $0.sourceFilePath == project.filePath && $0.shotKey == shotKey
        }) {
            var value = existing.bridgeValue(framesDirectoryURL: archiveFramesDirectoryURL)
            value["alreadyExists"] = true
            resolve(requestId: requestId, value: value)
            return
        }

        guard
            let encodedImage = imageDataURL.split(separator: ",", maxSplits: 1).last,
            let imageData = Data(base64Encoded: String(encodedImage))
        else {
            resolve(requestId: requestId, value: ["error": "没有取得当前画面"])
            return
        }

        let number = (payload["shotNumber"] as? NSNumber)?.intValue ?? 1
        let start = (payload["start"] as? NSNumber)?.doubleValue ?? 0
        let end = (payload["end"] as? NSNumber)?.doubleValue ?? start
        let capturedAt = (payload["capturedAt"] as? NSNumber)?.doubleValue ?? start
        let note = payload["note"] as? String ?? ""
        let tags = payload["tags"] as? [String] ?? []
        let id = UUID().uuidString
        let imageFileName = "\(id).jpg"
        let record = ArchiveFrameRecord(
            id: id,
            projectName: project.name,
            sourceFilePath: project.filePath,
            shotKey: shotKey,
            shotNumber: number,
            start: start,
            end: end,
            capturedAt: capturedAt,
            imageFileName: imageFileName,
            note: note,
            tags: tags,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try FileManager.default.createDirectory(
                at: archiveFramesDirectoryURL,
                withIntermediateDirectories: true
            )
            try imageData.write(
                to: archiveFramesDirectoryURL.appendingPathComponent(imageFileName),
                options: .atomic
            )
            records.append(record)
            try writeArchiveFrames(records)
            resolve(
                requestId: requestId,
                value: record.bridgeValue(framesDirectoryURL: archiveFramesDirectoryURL)
            )
        } catch {
            resolve(requestId: requestId, value: ["error": "静帧没有保存成功，请重试"])
        }
    }

    private func openArchiveFrame(payload: [String: Any]?, requestId: String) {
        guard
            let id = payload?["id"] as? String,
            let record = readArchiveFrames().first(where: { $0.id == id })
        else {
            resolve(requestId: requestId, value: ["error": "没有找到这份静帧资料"])
            return
        }
        guard FileManager.default.fileExists(atPath: record.sourceFilePath) else {
            resolve(
                requestId: requestId,
                value: [
                    "error": "原影片已经移动，请重新选择影片",
                    "needsRelink": true,
                ]
            )
            return
        }

        if let project = readProject(), project.filePath == record.sourceFilePath {
            resolve(requestId: requestId, value: project.bridgeValue)
            return
        }
        if let project = readProjectLibrary().first(where: { $0.filePath == record.sourceFilePath }) {
            writeProject(project)
            resolve(requestId: requestId, value: project.bridgeValue)
            return
        }

        let sourceURL = URL(fileURLWithPath: record.sourceFilePath)
        let values = try? sourceURL.resourceValues(forKeys: [.fileSizeKey])
        var cutPoints = [0.0]
        if record.start > 0.08 {
            cutPoints.append(record.start)
        }
        if record.end > (cutPoints.last ?? 0) + 0.08 {
            cutPoints.append(record.end)
        }
        let restoredData = restoredShotData(tags: record.tags, note: record.note)
        let restoredAnalysis: [String: Any] = [
            "mode": "manual",
            "cutPoints": cutPoints,
            "cutConfidence": [:],
            "shotData": [record.shotKey: restoredData],
        ]
        let restoredAnalysisJSON: String? = {
            guard
                let data = try? JSONSerialization.data(withJSONObject: restoredAnalysis),
                let text = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return text
        }()
        let project = ProjectRecord(
            name: record.projectName,
            filePath: record.sourceFilePath,
            compatibleFilePath: nil,
            size: UInt64(values?.fileSize ?? 0),
            duration: max(record.end, record.capturedAt),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            analysisJSON: restoredAnalysisJSON
        )
        writeProject(project)
        resolve(requestId: requestId, value: project.bridgeValue)
    }

    private func readArchiveClips() -> [ArchiveClipRecord] {
        guard
            let data = try? Data(contentsOf: archiveClipsFileURL),
            let records = try? JSONDecoder().decode([ArchiveClipRecord].self, from: data)
        else {
            return []
        }
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    private func writeArchiveClips(_ records: [ArchiveClipRecord]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(records)
        try data.write(to: archiveClipsFileURL, options: .atomic)
    }

    private func saveArchiveClip(payload: [String: Any]?, requestId: String) {
        guard
            let project = readProject(),
            let payload,
            let shotKey = payload["shotKey"] as? String,
            let imageDataURL = payload["imageDataUrl"] as? String
        else {
            resolve(requestId: requestId, value: ["error": "当前片段还不能收藏"])
            return
        }

        let start = (payload["start"] as? NSNumber)?.doubleValue ?? 0
        let end = (payload["end"] as? NSNumber)?.doubleValue ?? start
        guard end - start >= 0.2 else {
            resolve(requestId: requestId, value: ["error": "片段入点和出点无效"])
            return
        }

        var records = readArchiveClips()
        if let existing = records.first(where: {
            $0.sourceFilePath == project.filePath
                && abs($0.start - start) < 0.05
                && abs($0.end - end) < 0.05
        }) {
            var value = existing.bridgeValue(clipsDirectoryURL: archiveClipsDirectoryURL)
            value["alreadyExists"] = true
            resolve(requestId: requestId, value: value)
            return
        }

        guard
            let encodedImage = imageDataURL.split(separator: ",", maxSplits: 1).last,
            let imageData = Data(base64Encoded: String(encodedImage))
        else {
            resolve(requestId: requestId, value: ["error": "没有取得片段封面"])
            return
        }

        let number = (payload["shotNumber"] as? NSNumber)?.intValue ?? 1
        let capturedAt = (payload["capturedAt"] as? NSNumber)?.doubleValue ?? start
        let note = payload["note"] as? String ?? ""
        let tags = payload["tags"] as? [String] ?? []
        let id = UUID().uuidString
        let imageFileName = "\(id).jpg"
        let record = ArchiveClipRecord(
            id: id,
            projectName: project.name,
            sourceFilePath: project.filePath,
            shotKey: shotKey,
            shotNumber: number,
            start: start,
            end: end,
            capturedAt: capturedAt,
            imageFileName: imageFileName,
            note: note,
            tags: tags,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try FileManager.default.createDirectory(
                at: archiveClipsDirectoryURL,
                withIntermediateDirectories: true
            )
            try imageData.write(
                to: archiveClipsDirectoryURL.appendingPathComponent(imageFileName),
                options: .atomic
            )
            records.append(record)
            try writeArchiveClips(records)
            resolve(
                requestId: requestId,
                value: record.bridgeValue(clipsDirectoryURL: archiveClipsDirectoryURL)
            )
        } catch {
            resolve(requestId: requestId, value: ["error": "片段没有保存成功，请重试"])
        }
    }

    private func openArchiveClip(payload: [String: Any]?, requestId: String) {
        guard
            let id = payload?["id"] as? String,
            let record = readArchiveClips().first(where: { $0.id == id })
        else {
            resolve(requestId: requestId, value: ["error": "没有找到这份片段资料"])
            return
        }
        guard FileManager.default.fileExists(atPath: record.sourceFilePath) else {
            resolve(
                requestId: requestId,
                value: [
                    "error": "原影片已经移动，请重新选择影片",
                    "needsRelink": true,
                ]
            )
            return
        }

        if let project = readProject(), project.filePath == record.sourceFilePath {
            resolve(requestId: requestId, value: project.bridgeValue)
            return
        }
        if let project = readProjectLibrary().first(where: { $0.filePath == record.sourceFilePath }) {
            writeProject(project)
            resolve(requestId: requestId, value: project.bridgeValue)
            return
        }

        let sourceURL = URL(fileURLWithPath: record.sourceFilePath)
        let values = try? sourceURL.resourceValues(forKeys: [.fileSizeKey])
        var cutPoints = [0.0]
        let restoredShotStart: Double
        if record.start > 0.08 {
            cutPoints.append(record.start)
            restoredShotStart = record.start
        } else {
            restoredShotStart = 0
        }
        if record.end > (cutPoints.last ?? 0) + 0.08 {
            cutPoints.append(record.end)
        }
        let restoredShotKey = "shot-\(Int((restoredShotStart * 1000).rounded()))"
        let restoredData = restoredShotData(tags: record.tags, note: record.note)
        let restoredAnalysis: [String: Any] = [
            "mode": "manual",
            "cutPoints": cutPoints,
            "cutConfidence": [:],
            "shotData": [restoredShotKey: restoredData],
        ]
        let restoredAnalysisJSON: String? = {
            guard
                let data = try? JSONSerialization.data(withJSONObject: restoredAnalysis),
                let text = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return text
        }()
        let project = ProjectRecord(
            name: record.projectName,
            filePath: record.sourceFilePath,
            compatibleFilePath: nil,
            size: UInt64(values?.fileSize ?? 0),
            duration: record.end,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            analysisJSON: restoredAnalysisJSON
        )
        writeProject(project)
        resolve(requestId: requestId, value: project.bridgeValue)
    }

    private func relinkInspirationSource(payload: [String: Any]?, requestId: String) {
        guard
            let itemType = payload?["itemType"] as? String,
            let id = payload?["id"] as? String,
            ["frame", "clip"].contains(itemType)
        else {
            resolve(requestId: requestId, value: ["error": "没有找到需要恢复来源的资料"])
            return
        }

        let oldSourcePath: String?
        if itemType == "frame" {
            oldSourcePath = readArchiveFrames().first(where: { $0.id == id })?.sourceFilePath
        } else {
            oldSourcePath = readArchiveClips().first(where: { $0.id == id })?.sourceFilePath
        }
        guard let oldSourcePath else {
            resolve(requestId: requestId, value: ["error": "没有找到需要恢复来源的资料"])
            return
        }

        let panel = NSOpenPanel()
        panel.title = "原影片已经移动，请重新选择影片"
        panel.message = "选择一次后，这部影片下的全部静帧和片段都会恢复关联。"
        panel.prompt = "重新关联影片"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ["mp4", "mov", "m4v", "webm", "mkv", "avi"]
            .compactMap { UTType(filenameExtension: $0) }

        panel.beginSheetModal(for: mainWindow) { [weak self] response in
            guard let self else { return }
            guard response == .OK, let sourceURL = panel.url else {
                self.resolve(requestId: requestId, value: ["cancelled": true])
                return
            }

            do {
                var frames = self.readArchiveFrames()
                var clips = self.readArchiveClips()
                var changedFrames = false
                var changedClips = false

                for index in frames.indices where frames[index].sourceFilePath == oldSourcePath {
                    frames[index].sourceFilePath = sourceURL.path
                    changedFrames = true
                }
                for index in clips.indices where clips[index].sourceFilePath == oldSourcePath {
                    clips[index].sourceFilePath = sourceURL.path
                    changedClips = true
                }
                if changedFrames {
                    try self.writeArchiveFrames(frames)
                }
                if changedClips {
                    try self.writeArchiveClips(clips)
                }

                if
                    var project = self.readStoredProject(),
                    project.filePath == oldSourcePath
                {
                    let values = try? sourceURL.resourceValues(forKeys: [.fileSizeKey])
                    project.filePath = sourceURL.path
                    project.compatibleFilePath = nil
                    project.size = UInt64(values?.fileSize ?? 0)
                    project.updatedAt = ISO8601DateFormatter().string(from: Date())
                    self.writeProject(project)
                }

                if itemType == "frame" {
                    self.openArchiveFrame(payload: ["id": id], requestId: requestId)
                } else {
                    self.openArchiveClip(payload: ["id": id], requestId: requestId)
                }
            } catch {
                self.resolve(requestId: requestId, value: ["error": "影片关联没有恢复成功，请重试"])
            }
        }
    }

    private func analyzeLocalVideo(requestId: String) {
        guard let project = readProject() else {
            resolve(requestId: requestId, value: ["error": "请先导入影片"])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                var (activeProject, fileURL) = try self.ensureReadableAnalysisVideo(
                    for: project,
                    requestId: requestId
                )
                let analysisProgress: (Int, Double) -> Void = { percent, seconds in
                    DispatchQueue.main.async {
                        self.sendProgress(
                            requestId: requestId,
                            value: [
                                "percent": percent,
                                "seconds": seconds,
                            ]
                        )
                    }
                }

                let analysis: LocalShotAnalysis
                do {
                    analysis = try LocalShotDetector.analyze(
                        url: fileURL,
                        progress: analysisProgress
                    )
                } catch {
                    guard
                        activeProject.compatibleFilePath == nil,
                        fileURL.path == activeProject.filePath,
                        self.protectedVideoMarker(in: fileURL) == nil
                    else {
                        throw error
                    }

                    let proxyURL = try self.createCompatibleVideoProxy(from: fileURL) { percent, message in
                        DispatchQueue.main.async {
                            self.sendProgress(
                                requestId: requestId,
                                value: [
                                    "phase": "compatibility",
                                    "percent": percent,
                                    "message": message,
                                ]
                            )
                        }
                    }
                    activeProject.compatibleFilePath = proxyURL.path
                    activeProject.updatedAt = ISO8601DateFormatter().string(from: Date())
                    self.writeProject(activeProject)
                    DispatchQueue.main.async {
                        self.sendProgress(
                            requestId: requestId,
                            value: [
                                "phase": "compatibility",
                                "percent": 32,
                                "message": "兼容副本已生成，开始分析镜头…",
                            ]
                        )
                    }
                    fileURL = proxyURL
                    analysis = try LocalShotDetector.analyze(
                        url: fileURL,
                        progress: analysisProgress
                    )
                }
                let cuts = analysis.candidates.map {
                    [
                        "time": $0.time,
                        "confidence": $0.confidence,
                    ]
                }
                DispatchQueue.main.async {
                    self.resolve(
                        requestId: requestId,
                        value: [
                            "duration": analysis.duration,
                            "frameCount": analysis.frameCount,
                            "cuts": cuts,
                            "usingCompatibleCopy": activeProject.compatibleFilePath != nil,
                        ]
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.resolve(
                        requestId: requestId,
                        value: ["error": error.localizedDescription]
                    )
                }
            }
        }
    }

    private func generateRepresentativeFrames(payload: [String: Any]?, requestId: String) {
        guard
            let project = readProject(),
            let shotValues = payload?["shots"] as? [[String: Any]]
        else {
            resolve(requestId: requestId, value: ["error": "当前镜头还不能生成代表静帧"])
            return
        }

        let shots = shotValues.compactMap { value -> RepresentativeFrameGenerator.Shot? in
            guard
                let key = value["key"] as? String,
                let start = (value["start"] as? NSNumber)?.doubleValue,
                let end = (value["end"] as? NSNumber)?.doubleValue,
                end > start
            else {
                return nil
            }
            return RepresentativeFrameGenerator.Shot(key: key, start: start, end: end)
        }
        guard !shots.isEmpty else {
            resolve(requestId: requestId, value: [:])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let results = try RepresentativeFrameGenerator.generate(
                    videoURL: self.analysisVideoURL(for: project),
                    shots: shots,
                    rootDirectoryURL: self.supportDirectoryURL
                ) { percent in
                    DispatchQueue.main.async {
                        self.sendProgress(
                            requestId: requestId,
                            value: ["percent": percent]
                        )
                    }
                }
                let value = results.mapValues(\.bridgeValue)
                DispatchQueue.main.async {
                    self.resolve(requestId: requestId, value: value)
                }
            } catch {
                DispatchQueue.main.async {
                    self.resolve(
                        requestId: requestId,
                        value: ["error": error.localizedDescription]
                    )
                }
            }
        }
    }

    private func saveRepresentativeFrame(payload: [String: Any]?, requestId: String) {
        guard
            let project = readProject(),
            let payload,
            let shotKey = payload["shotKey"] as? String,
            let imageDataURL = payload["imageDataUrl"] as? String
        else {
            resolve(requestId: requestId, value: ["error": "当前画面还不能设为代表静帧"])
            return
        }

        do {
            let result = try RepresentativeFrameGenerator.saveManualFrame(
                imageDataURL: imageDataURL,
                shotKey: shotKey,
                capturedAt: (payload["capturedAt"] as? NSNumber)?.doubleValue ?? 0,
                sourcePath: project.filePath,
                rootDirectoryURL: supportDirectoryURL
            )
            resolve(requestId: requestId, value: result.bridgeValue)
        } catch {
            resolve(requestId: requestId, value: ["error": "代表静帧没有保存成功，请重试"])
        }
    }

    private func analyzeBasicScenes(payload: [String: Any]?, requestId: String) {
        guard
            readProject() != nil,
            let frameValues = payload?["frames"] as? [[String: Any]]
        else {
            resolve(requestId: requestId, value: ["error": "请先导入影片并生成代表静帧"])
            return
        }

        let frames = frameValues.compactMap { value -> BasicSceneFrame? in
            guard
                let shotKey = value["shotKey"] as? String,
                let imageURLText = value["imageUrl"] as? String,
                let imageURL = URL(string: imageURLText),
                imageURL.isFileURL
            else {
                return nil
            }
            return BasicSceneFrame(shotKey: shotKey, imageURL: imageURL)
        }
        guard !frames.isEmpty else {
            resolve(requestId: requestId, value: ["error": "当前镜头还没有可以识别的代表静帧"])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let results = try BasicSceneAnalyzer.analyze(frames: frames) { percent in
                    DispatchQueue.main.async {
                        self.sendProgress(
                            requestId: requestId,
                            value: ["percent": percent]
                        )
                    }
                }
                DispatchQueue.main.async {
                    self.resolve(
                        requestId: requestId,
                        value: results.mapValues(\.bridgeValue)
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.resolve(
                        requestId: requestId,
                        value: ["error": error.localizedDescription]
                    )
                }
            }
        }
    }

    private func resolve(requestId: String, value: Any?) {
        let requestJSON = jsonString(requestId)
        let valueJSON = jsonString(value ?? NSNull())
        webView.evaluateJavaScript("window.__cinemaNativeResolve(\(requestJSON), \(valueJSON));")
    }

    private func sendProgress(requestId: String, value: Any) {
        let requestJSON = jsonString(requestId)
        let valueJSON = jsonString(value)
        webView.evaluateJavaScript("window.__cinemaNativeProgress(\(requestJSON), \(valueJSON));")
    }

    private func jsonString(_ value: Any) -> String {
        guard
            JSONSerialization.isValidJSONObject(["value": value]),
            let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
            let text = String(data: data, encoding: .utf8)
        else {
            return "null"
        }
        return text
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(url.isFileURL || url.scheme == "about" ? .allow : .cancel)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }

        let childWebView = WKWebView(frame: .zero, configuration: configuration)
        childWebView.navigationDelegate = self

        let childWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        childWindow.title = "拉片报告预览"
        childWindow.contentView = childWebView
        childWindow.center()
        childWindow.makeKeyAndOrderFront(nil)
        childWindows.append(childWindow)

        return childWebView
    }

    private var bridgeScript: String {
        """
        (() => {
          const callbacks = new Map();
          let requestNumber = 0;

          window.__cinemaNativeResolve = (requestId, value) => {
            const entry = callbacks.get(requestId);
            if (!entry) return;
            callbacks.delete(requestId);
            entry.resolve(value);
          };

          window.__cinemaNativeProgress = (requestId, value) => {
            callbacks.get(requestId)?.onProgress?.(value);
          };

          const callNative = (action, payload = null, onProgress = null) => new Promise((resolve) => {
            const requestId = `request-${++requestNumber}`;
            callbacks.set(requestId, { resolve, onProgress });
            window.webkit.messageHandlers.cinemaDesktop.postMessage({
              requestId,
              action,
              payload
            });
          });

          window.cinemaDesktop = {
            selectVideo: () => callNative("selectVideo"),
            getRecentProject: () => callNative("getRecentProject"),
            getProjectLibrary: () => callNative("getProjectLibrary"),
            getProjectCategories: () => callNative("getProjectCategories"),
            createProjectCategory: (category) => callNative("createProjectCategory", category),
            openProjectFromLibrary: (project) => callNative("openProjectFromLibrary", project),
            removeProjectFromLibrary: (project) => callNative("removeProjectFromLibrary", project),
            updateProjectCategory: (project) => callNative("updateProjectCategory", project),
            updateProject: (updates) => callNative("updateProject", updates),
            saveAnalysis: (analysis) => callNative("saveAnalysis", analysis),
            getInspirationCollections: () => callNative("getInspirationCollections"),
            createInspirationCollection: (collection) => callNative("createInspirationCollection", collection),
            updateInspirationCollection: (collection) => callNative("updateInspirationCollection", collection),
            deleteInspirationCollection: (collection) => callNative("deleteInspirationCollection", collection),
            touchInspirationCollection: (collection) => callNative("touchInspirationCollection", collection),
            getInspirationMemberships: () => callNative("getInspirationMemberships"),
            addArchiveRecordToInspiration: (membership) => callNative("addArchiveRecordToInspiration", membership),
            removeArchiveFromInspiration: (membership) => callNative("removeArchiveFromInspiration", membership),
            getInspirationNotes: () => callNative("getInspirationNotes"),
            upsertInspirationNote: (note) => callNative("upsertInspirationNote", note),
            getInspirationImages: () => callNative("getInspirationImages"),
            importInspirationImages: (options) => callNative("importInspirationImages", options),
            analyzeLocalVideo: (onProgress) => callNative("analyzeLocalVideo", null, onProgress),
            generateRepresentativeFrames: (shots, onProgress) => callNative("generateRepresentativeFrames", { shots }, onProgress),
            analyzeBasicScenes: (frames, onProgress) => callNative("analyzeBasicScenes", { frames }, onProgress),
            saveRepresentativeFrame: (frame) => callNative("saveRepresentativeFrame", frame),
            getArchiveFrames: () => callNative("getArchiveFrames"),
            saveArchiveFrame: (frame) => callNative("saveArchiveFrame", frame),
            updateArchiveTags: (changes) => callNative("updateArchiveTags", changes),
            updateArchiveNote: (changes) => callNative("updateArchiveNote", changes),
            syncArchiveShot: (changes) => callNative("syncArchiveShot", changes),
            syncArchiveRepresentativeFrame: (changes) => callNative("syncArchiveRepresentativeFrame", changes),
            openArchiveFrame: (record) => callNative("openArchiveFrame", record),
            getArchiveClips: () => callNative("getArchiveClips"),
            saveArchiveClip: (clip) => callNative("saveArchiveClip", clip),
            openArchiveClip: (record) => callNative("openArchiveClip", record),
            relinkInspirationSource: (record) => callNative("relinkInspirationSource", record),
            exportExcel: (report) => callNative("exportExcel", report),
            exportFramePackage: (packageData) => callNative("exportFramePackage", packageData),
            createLocalBackup: () => callNative("createLocalBackup"),
            selectRestoreBackup: () => callNative("selectRestoreBackup"),
            restoreSelectedBackup: () => callNative("restoreSelectedBackup"),
            getAITranslationSettings: () => callNative("getAITranslationSettings"),
            saveAITranslationKey: (settings) => callNative("saveAITranslationKey", settings),
            removeAITranslationKey: () => callNative("removeAITranslationKey"),
            translateSubtitles: (subtitles, onProgress) => callNative("translateSubtitles", subtitles, onProgress),
            getCloudSubtitleSettings: () => callNative("getCloudSubtitleSettings"),
            saveCloudSubtitleKey: (settings) => callNative("saveCloudSubtitleKey", settings),
            removeCloudSubtitleKey: () => callNative("removeCloudSubtitleKey"),
            extractCloudSubtitles: (options, onProgress) => callNative("extractCloudSubtitles", options, onProgress),
            readSubtitles: () => callNative("readSubtitles")
          };
        })();
        """
    }
}

@main
struct DirectorWorkbenchAppRunner {
    private static let delegate = DirectorWorkbenchApp()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        delegate.startApplication()
        application.run()
    }
}
