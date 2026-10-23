import Cocoa
import WebKit

final class BugFixWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
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
                window.__testImportedImages = [];
                window.__testProject = {
                  name: "用户流程测试影片",
                  filePath: "/tmp/user-flow-test.mov",
                  fileUrl: window.__testVideoUrl,
                  duration: 16,
                  updatedAt: new Date().toISOString(),
                  analysis: {
                    mode: "local",
                    cutPoints: [0, 4, 8, 16],
                    cutConfidence: { "shot-4000": 0.9, "shot-8000": 0.8 },
                    shotData: {
                      "shot-0": { size: "中景", angle: "平视", movement: "固定", note: "第一镜笔记" },
                      "shot-4000": { size: "近景", angle: "平视", movement: "固定", note: "" },
                      "shot-8000": { size: "全景", angle: "平视", movement: "固定", note: "" }
                    },
                    representativeFrames: {
                      "shot-0": { shotKey: "shot-0", capturedAt: 2, imageUrl: "./assets/still-01.png", source: "auto" }
                    }
                  }
                };
                window.cinemaDesktop = {
                  getRecentProject: async () => window.__testProject,
                  getProjectLibrary: async () => [window.__testProject],
                  openProjectFromLibrary: async () => window.__testProject,
                  getArchiveFrames: async () => [{
                    id: "frame-1",
                    projectName: "用户流程测试影片",
                    sourceFilePath: "/tmp/user-flow-test.mov",
                    sourceFileUrl: window.__testVideoUrl,
                    shotKey: "shot-0",
                    shotNumber: 1,
                    start: 0,
                    end: 4,
                    capturedAt: 2,
                    imageUrl: "./assets/still-01.png",
                    note: "第一镜笔记",
                    tags: ["中景"],
                    createdAt: new Date().toISOString()
                  }],
                  getArchiveClips: async () => [{
                    id: "clip-1",
                    type: "clip",
                    projectName: "用户流程测试影片",
                    sourceFilePath: "/tmp/user-flow-test.mov",
                    sourceFileUrl: window.__testVideoUrl,
                    shotKey: "shot-4000",
                    shotNumber: 2,
                    start: 4,
                    end: 8,
                    capturedAt: 5,
                    imageUrl: "./assets/still-02.png",
                    note: "片段笔记",
                    tags: ["近景"],
                    createdAt: new Date().toISOString()
                  }],
                  openArchiveClip: async () => window.__testProject,
                  getInspirationCollections: async () => [{
                    id: "collection-1",
                    name: "测试收藏夹",
                    description: "用于用户流程测试",
                    createdAt: new Date().toISOString(),
                    updatedAt: new Date().toISOString(),
                    lastUsedAt: new Date().toISOString()
                  }],
                  getInspirationMemberships: async () => [],
                  getInspirationNotes: async () => [],
                  getInspirationImages: async () => window.__testImportedImages,
                  importInspirationImages: async () => {
                    window.__testImportedImages = [{
                      id: "image-1",
                      title: "测试导入图片",
                      imageUrl: "./assets/still-03.png",
                      note: "",
                      collectionIds: ["collection-1"],
                      createdAt: new Date().toISOString(),
                      updatedAt: new Date().toISOString()
                    }];
                    return { importedCount: 1, images: window.__testImportedImages };
                  },
                  updateProject: async (updates) => ({ ...window.__testProject, duration: updates.duration || 16 }),
                  saveAnalysis: async (analysis) => {
                    window.__testSavedAnalysis = JSON.parse(JSON.stringify(analysis));
                    window.__testProject = { ...window.__testProject, analysis: window.__testSavedAnalysis };
                    return window.__testProject;
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
        webView.loadFileURL(
            root.appendingPathComponent("preview/index.html"),
            allowingReadAccessTo: URL(fileURLWithPath: "/")
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
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
        let videoJSON = String(
            data: try! JSONSerialization.data(withJSONObject: videoURL, options: [.fragmentsAllowed]),
            encoding: .utf8
        )!

        webView.evaluateJavaScript("window.__testVideoUrl = \(videoJSON); window.__testProject.fileUrl = window.__testVideoUrl;")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            webView.evaluateJavaScript(
                """
                window.__bugFlowDone = false;
                (async () => {
                  applyLocalProject(window.__testProject, false);
                  await loadArchiveFrames();
                  await loadInspirationCollections();
                  renderLibraryProjects();

                  globalSearchInput.value = "用户流程";
                  globalSearchInput.dispatchEvent(new Event("input", { bubbles: true }));
                  window.__searchedCards = document.querySelectorAll("#project-grid .project-card:not(.library-empty-card)").length;

                  document.querySelector('[data-action="preview"]').click();
                  window.__overviewOpen = !projectOverviewOverlay.hidden
                    && overviewShotCount.textContent === "3"
                    && overviewFrameCount.textContent === "1"
                    && overviewClipCount.textContent === "1";
                  closeProjectOverview();

                  selectManualShot("shot-4000");
                  openMoveCutDialog();
                  window.__moveOpened = !moveCutOverlay.hidden;
                  moveCutSlider.value = "5";
                  moveCutSlider.dispatchEvent(new Event("input", { bubbles: true }));
                  moveCutConfirm.click();
                  window.__movedCut = Math.abs(manualAnalysis.cutPoints[1] - 5) < 0.05;

                  const beforeZoom = timelineZoomLabel.textContent;
                  timelineZoomInButton.click();
                  window.__zoomChanged = beforeZoom !== timelineZoomLabel.textContent;

                  const reportUrl = reportUrlFor({ print: true });
                  window.__reportHasData = reportUrl.hash.includes("data=");

                  openPage("archive");
                  renderArchiveFrames();
                  await playArchiveClip(archiveClips[0]);
                  window.__clipPlaybackReady = Math.abs(activeClipPlaybackEnd - 8) < 0.05;

                  openPage("inspiration");
                  await addImportedInspirationImages();
                  window.__bugFlowDone = true;
                })();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            webView.evaluateJavaScript(
                """
                JSON.stringify({
                  done: window.__bugFlowDone,
                  searchedCards: window.__searchedCards,
                  overviewOpen: window.__overviewOpen,
                  moveOpened: window.__moveOpened,
                  movedCut: window.__movedCut,
                  zoomChanged: window.__zoomChanged,
                  reportHasData: window.__reportHasData,
                  clipPlaybackReady: window.__clipPlaybackReady,
                  importedImages: document.querySelectorAll('[data-inspiration-type="image"][data-real-inspiration="true"]').length,
                  libraryTitle: document.querySelector(".continue-copy h3").textContent
                })
                """
            ) { value, error in
                if let error {
                    fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                    self.finished = true
                    NSApp.terminate(nil)
                    return
                }
                guard
                    let json = value as? String,
                    let data = json.data(using: .utf8),
                    let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    result["done"] as? Bool == true,
                    result["searchedCards"] as? Int == 1,
                    result["overviewOpen"] as? Bool == true,
                    result["moveOpened"] as? Bool == true,
                    result["movedCut"] as? Bool == true,
                    result["zoomChanged"] as? Bool == true,
                    result["reportHasData"] as? Bool == true,
                    result["clipPlaybackReady"] as? Bool == true,
                    (result["importedImages"] as? Int ?? 0) >= 1,
                    (result["libraryTitle"] as? String)?.contains("用户流程测试影片") == true
                else {
                    fputs("TEST_ERROR invalid bug fix workflow \(value as? String ?? "nil")\n", stderr)
                    self.finished = true
                    NSApp.terminate(nil)
                    return
                }
                self.finished = true
                print("BUG_FIX_WORKFLOW_TEST_OK")
                NSApp.terminate(nil)
            }
        }
    }
}

@main
struct BugFixWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = BugFixWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
