import Cocoa
import WebKit

final class ManualWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__testSavedAnalysis = null;
                window.__testArchiveFrames = [];
                window.__testArchiveClips = [];
                window.__testExcelReport = null;
                window.__testFramePackage = null;
                window.cinemaDesktop = {
                  selectVideo: async () => ({
                    name: "自动测试影片",
                    filePath: "",
                    fileUrl: window.__testVideoUrl,
                    duration: 0,
                    analysis: null
                  }),
                  getRecentProject: async () => null,
                  readSubtitles: async () => ({
                    found: true,
                    sourceType: "external",
                    sourceName: "自动测试影片.zh-CN.srt",
                    language: "zh-CN",
                    isChinese: true,
                    candidateCount: 2,
                    cueCount: 2,
                    cues: [
                      { start: 1, end: 2.5, text: "第一句中文字幕" },
                      { start: 4, end: 6, text: "第二句中文字幕" }
                    ],
                    scannedAt: new Date().toISOString()
                  }),
                  updateProject: async (updates) => ({
                    name: "自动测试影片",
                    filePath: "",
                    fileUrl: window.__testVideoUrl,
                    duration: updates.duration || 0,
                    analysis: window.__testSavedAnalysis
                  }),
                  analyzeLocalVideo: async (onProgress) => {
                    onProgress?.({ percent: 42, seconds: 6 });
                    onProgress?.({ percent: 100, seconds: 16 });
                    return {
                      duration: document.querySelector("#local-video")?.duration || 16,
                      frameCount: 420,
                      cuts: [
                        { time: 1.2, confidence: 0.92 },
                        { time: 2.8, confidence: 0.72 }
                      ]
                    };
                  },
                  saveAnalysis: async (analysis) => {
                    window.__testSavedAnalysis = JSON.parse(JSON.stringify(analysis));
                    return {
                      name: "自动测试影片",
                      filePath: "",
                      fileUrl: window.__testVideoUrl,
                      duration: document.querySelector("#local-video")?.duration || 0,
                      analysis: window.__testSavedAnalysis
                    };
                  },
                  generateRepresentativeFrames: async (shots, onProgress) => {
                    onProgress?.({ percent: 100 });
                    return Object.fromEntries(shots.map((shot, index) => [
                      shot.key,
                      {
                        shotKey: shot.key,
                        capturedAt: shot.start + (shot.end - shot.start) * 0.5,
                        imageUrl: `./assets/still-0${(index % 9) + 1}.png`,
                        source: "auto"
                      }
                    ]));
                  },
                  saveRepresentativeFrame: async (frame) => ({
                    shotKey: frame.shotKey,
                    capturedAt: frame.capturedAt,
                    imageUrl: frame.imageDataUrl,
                    source: "manual"
                  }),
                  getArchiveFrames: async () => window.__testArchiveFrames,
                  saveArchiveFrame: async (frame) => {
                    const record = {
                      id: `frame-${window.__testArchiveFrames.length + 1}`,
                      projectName: "自动测试影片",
                      sourceFilePath: "",
                      sourceFileUrl: window.__testVideoUrl,
                      shotKey: frame.shotKey,
                      shotNumber: frame.shotNumber,
                      start: frame.start,
                      end: frame.end,
                      capturedAt: frame.capturedAt,
                      imageUrl: frame.imageDataUrl,
                      note: frame.note,
                      tags: frame.tags,
                      createdAt: new Date().toISOString()
                    };
                    window.__testArchiveFrames.unshift(record);
                    return record;
                  },
                  openArchiveFrame: async () => ({
                    name: "自动测试影片",
                    filePath: "",
                    fileUrl: window.__testVideoUrl,
                    duration: document.querySelector("#local-video")?.duration || 0,
                    analysis: window.__testSavedAnalysis
                  }),
                  getArchiveClips: async () => window.__testArchiveClips,
                  saveArchiveClip: async (clip) => {
                    const record = {
                      id: `clip-${window.__testArchiveClips.length + 1}`,
                      type: "clip",
                      projectName: "自动测试影片",
                      sourceFilePath: "",
                      sourceFileUrl: window.__testVideoUrl,
                      shotKey: clip.shotKey,
                      shotNumber: clip.shotNumber,
                      start: clip.start,
                      end: clip.end,
                      capturedAt: clip.capturedAt,
                      imageUrl: clip.imageDataUrl,
                      note: clip.note,
                      tags: clip.tags,
                      createdAt: new Date().toISOString()
                    };
                    window.__testArchiveClips.unshift(record);
                    return record;
                  },
                  openArchiveClip: async () => ({
                    name: "自动测试影片",
                    filePath: "",
                    fileUrl: window.__testVideoUrl,
                    duration: document.querySelector("#local-video")?.duration || 0,
                    analysis: window.__testSavedAnalysis
                  }),
                  exportExcel: async (report) => {
                    window.__testExcelReport = JSON.parse(JSON.stringify(report));
                    return { fileName: "自动测试影片-专业图文拉片表.xlsx" };
                  },
                  exportFramePackage: async (packageData) => {
                    window.__testFramePackage = JSON.parse(JSON.stringify(packageData));
                    return {
                      fileName: "自动测试影片-导演静帧资料包.zip",
                      frameCount: packageData.frames.length
                    };
                  }
                };
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 920), configuration: configuration)
        webView.navigationDelegate = self
        window = NSWindow(
            contentRect: NSRect(x: -2000, y: -2000, width: 1440, height: 920),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.orderFront(nil)

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let indexURL = root.appendingPathComponent("preview/index.html")
        webView.loadFileURL(indexURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))

        DispatchQueue.main.asyncAfter(deadline: .now() + 14) {
            if !self.finished {
                fputs("TEST_ERROR timeout\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let videoURL = URL(
            fileURLWithPath: "/System/Library/CoreServices/ControlCenter.app/Contents/Resources/BentoGalleryIntroduction.mov"
        ).absoluteString
        let project: [String: Any] = [
            "name": "自动测试影片",
            "filePath": "",
            "fileUrl": videoURL,
            "duration": 0,
        ]
        let data = try! JSONSerialization.data(withJSONObject: project)
        let projectJSON = String(data: data, encoding: .utf8)!
        let videoJSON = String(
            data: try! JSONSerialization.data(withJSONObject: videoURL, options: [.fragmentsAllowed]),
            encoding: .utf8
        )!

        webView.evaluateJavaScript(
            "window.__testVideoUrl = \(videoJSON); window.__testProject = \(projectJSON); importLocalVideo();"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            webView.evaluateJavaScript(
                """
                startLocalAnalysis();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            webView.evaluateJavaScript(
                """
                localVideo.pause();
                localVideo.currentTime = Math.min(4, localVideo.duration / 2);
                addManualCutPoint();
                directorNote.value = "自动测试：人物在停顿中完成关系变化。";
                directorNote.dispatchEvent(new Event("input", { bubbles: true }));
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
            webView.evaluateJavaScript(
                """
                setCurrentFrameAsRepresentative();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            webView.evaluateJavaScript(
                """
                archiveCurrentFrame();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            webView.evaluateJavaScript(
                """
                archiveCurrentShotClip();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
            webView.evaluateJavaScript(
                """
                localVideo.currentTime = 4.5;
                setClipInButton.click();
                localVideo.currentTime = 6.5;
                setClipOutButton.click();
                saveCustomClipButton.click();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 7.4) {
            webView.evaluateJavaScript(
                """
                archiveSearchInput.value = "中景";
                archiveSearchInput.dispatchEvent(new Event("input", { bubbles: true }));
                openArchiveFrameRecord(window.__testArchiveFrames[0]);
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            webView.evaluateJavaScript(
                """
                openArchiveClipRecord(window.__testArchiveClips[0]);
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8.5) {
            webView.evaluateJavaScript(
                """
                openPage("export");
                refreshReportWorkspace();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) {
            webView.evaluateJavaScript(
                """
                exportExcelWorkbook();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 9.4) {
            webView.evaluateJavaScript(
                """
                exportDirectorFramePackage();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10.4) {
            webView.evaluateJavaScript(
                """
                const reportDocument = reportFrame.contentDocument;
                JSON.stringify({
                  duration: localVideo.duration,
                  shotCount: document.querySelectorAll(".manual-shot").length,
                  summary: document.querySelector("#timeline-summary").textContent,
                  choiceClosed: document.querySelector("#analysis-choice").hidden,
                  mode: window.__testSavedAnalysis?.mode,
                  subtitleCount: window.__testSavedAnalysis?.subtitles?.cues?.length || 0,
                  subtitleSource: window.__testSavedAnalysis?.subtitles?.sourceName,
                  subtitleAssignmentCount: window.__testSavedAnalysis?.subtitleAssignments?.assignedCueCount || 0,
                  subtitleMappedShotCount: Object.keys(
                    window.__testSavedAnalysis?.subtitleAssignments?.byShot || {}
                  ).length,
                  firstSubtitleMappedShotCount: Object.values(
                    window.__testSavedAnalysis?.subtitleAssignments?.byShot || {}
                  ).filter((shot) => shot.cues?.some((cue) => cue.cueIndex === 0)).length,
                  secondSubtitleShot: window.__testSavedAnalysis
                    ?.subtitleAssignments?.byShot?.["shot-4000"]?.text,
                  confidenceLabels: document.querySelectorAll(".cut-confidence").length,
                  representativeFrameCount: Object.keys(window.__testSavedAnalysis?.representativeFrames || {}).length,
                  representativeThumbnails: document.querySelectorAll(".manual-shot .representative-thumbnail").length,
                  manualRepresentative: Object.values(window.__testSavedAnalysis?.representativeFrames || {})
                    .some((frame) => frame.source === "manual"),
                  representativeStatus: document.querySelector("#representative-frame-status").textContent,
                  savedCutPoints: window.__testSavedAnalysis?.cutPoints?.length || 0,
                  archiveCount: window.__testArchiveFrames.length,
                  archiveCards: document.querySelectorAll("#memory-grid .memory-card").length,
                  archiveStat: document.querySelector("#archive-frame-count").textContent,
                  archiveEmptyHidden: document.querySelector("#archive-empty").hidden,
                  archiveNote: window.__testArchiveFrames[0]?.note,
                  archiveTargetTime: window.__testArchiveFrames[0]?.capturedAt,
                  clipCount: window.__testArchiveClips.length,
                  clipCards: document.querySelectorAll('#memory-grid .memory-card[data-type="clip"]').length,
                  clipStat: document.querySelector("#archive-clip-count").textContent,
                  clipStart: window.__testArchiveClips[0]?.start,
                  clipEnd: window.__testArchiveClips[0]?.end,
                  clipPlayingTo: activeClipPlaybackEnd,
                  returnedTime: localVideo.currentTime,
                  reportProject: latestReportData?.project?.name,
                  reportShotCount: latestReportData?.shots?.length,
                  reportFrameCount: latestReportData?.frameCount,
                  reportPages: reportDocument?.querySelectorAll(".report-page[data-page-key]").length,
                  reportRows: reportDocument?.querySelectorAll(".shot-row:not(.shot-head)").length,
                  reportTitle: reportDocument?.querySelector(".cover-copy h1")?.textContent,
                  reportDialogue: latestReportData?.shots?.find((shot) => shot.dialogueText)?.dialogueText,
                  reportMissingFrames: reportDocument?.querySelectorAll(".shot-image .report-image-empty").length,
                  reportPageCountLabel: document.querySelector("#export-page-count").textContent,
                  excelShotCount: window.__testExcelReport?.shots?.length,
                  excelFrameCount: window.__testExcelReport?.frameCount,
                  excelDialogue: window.__testExcelReport?.shots?.find((shot) => shot.dialogueText)?.dialogueText,
                  excelButtonEnabled: !document.querySelector('[data-action="export-excel"]').disabled,
                  framePackageCount: window.__testFramePackage?.frames?.length,
                  framePackageProject: window.__testFramePackage?.project?.name,
                  framePackageButtonEnabled: !document.querySelector('[data-action="export-frames"]').disabled,
                  savedNote: Object.values(window.__testSavedAnalysis?.shotData || {})
                    .some((shot) => shot.note === "自动测试：人物在停顿中完成关系变化。")
                })
                """
            ) { value, error in
                if let error {
                    fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                    self.finished = true
                    NSApp.terminate(nil)
                    return
                }
                self.finished = true
                print(value as? String ?? "TEST_ERROR missing result")
                NSApp.terminate(nil)
            }
        }
    }
}

@main
struct ManualWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = ManualWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
