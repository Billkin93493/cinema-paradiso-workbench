import Cocoa
import WebKit

final class InspirationSourceWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__sourceOpenCalls = 0;
                window.__sourceRelinkCalls = 0;
                window.__sourceNeedsRelink = false;
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [{
                    id: "source-frame",
                    projectName: "来源测试影片",
                    sourceFilePath: "/tmp/source-old.mov",
                    shotKey: "shot-0",
                    shotNumber: 1,
                    start: 0,
                    end: 4,
                    capturedAt: 2,
                    imageUrl: "./assets/still-05.png",
                    note: "来源测试静帧",
                    tags: ["中景", "平视", "固定"],
                    createdAt: "2026-06-14T10:00:00.000Z"
                  }],
                  getArchiveClips: async () => [{
                    id: "source-clip",
                    projectName: "来源测试影片",
                    sourceFilePath: "/tmp/source-old.mov",
                    shotKey: "shot-1",
                    shotNumber: 2,
                    start: 4,
                    end: 8,
                    capturedAt: 5,
                    imageUrl: "./assets/still-07.png",
                    note: "来源测试片段",
                    tags: ["近景", "平视", "固定"],
                    createdAt: "2026-06-14T09:00:00.000Z"
                  }],
                  getInspirationCollections: async () => [{
                    id: "source-collection",
                    name: "来源收藏夹",
                    description: "检查来源追溯和浏览位置恢复。",
                    createdAt: "2026-06-14T08:00:00.000Z",
                    updatedAt: "2026-06-14T08:00:00.000Z",
                    lastUsedAt: "2026-06-14T08:00:00.000Z"
                  }],
                  getInspirationMemberships: async () => [
                    {
                      id: "source-membership-frame",
                      collectionId: "source-collection",
                      itemType: "frame",
                      itemId: "source-frame",
                      addedAt: "2026-06-14T10:00:00.000Z"
                    },
                    {
                      id: "source-membership-clip",
                      collectionId: "source-collection",
                      itemType: "clip",
                      itemId: "source-clip",
                      addedAt: "2026-06-14T09:00:00.000Z"
                    }
                  ],
                  getInspirationNotes: async () => [],
                  touchInspirationCollection: async () => null,
                  openArchiveFrame: async () => {
                    window.__sourceOpenCalls += 1;
                    if (window.__sourceNeedsRelink) {
                      return { error: "原影片已经移动，请重新选择影片", needsRelink: true };
                    }
                    return {
                      name: "来源测试影片",
                      filePath: "/tmp/source-old.mov",
                      fileUrl: "file:///tmp/source-old.mov",
                      size: 1,
                      duration: 8,
                      updatedAt: "2026-06-14T10:00:00.000Z",
                      analysis: {
                        mode: "manual",
                        cutPoints: [0, 4, 8],
                        shotData: {}
                      }
                    };
                  },
                  relinkInspirationSource: async () => {
                    window.__sourceRelinkCalls += 1;
                    window.__sourceNeedsRelink = false;
                    return {
                      name: "来源测试影片",
                      filePath: "/tmp/source-new.mov",
                      fileUrl: "file:///tmp/source-new.mov",
                      size: 1,
                      duration: 8,
                      updatedAt: "2026-06-14T10:01:00.000Z",
                      analysis: {
                        mode: "manual",
                        cutPoints: [0, 4, 8],
                        shotData: {}
                      }
                    };
                  }
                };
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 1440, height: 920),
            configuration: configuration
        )
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if !self.finished {
                fputs("TEST_ERROR timeout\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.webView.evaluateJavaScript(
                """
                window.__inspirationSourceWorkflowResult = null;
                (async () => {
                  openPage("inspiration");
                  await loadInspirationCollections();
                  selectInspirationCollection("source-collection", { touch: false });
                  selectInspirationFilter("frame");
                  inspirationSearchInput.value = "来源测试";
                  updateInspirationResults();

                  const frameCard = document.querySelector(
                    '[data-real-inspiration="true"][data-item-id="source-frame"]'
                  );
                  openInspirationPreview(frameCard);
                  const returnButtonVisible = !inspirationReturnSource.hidden;
                  await openInspirationSource(frameCard);
                  const openedWorkbench = document.querySelector("#workbench-page").classList.contains("active");

                  openPage("inspiration");
                  await new Promise((resolve) => setTimeout(resolve, 250));
                  const restoredState = activeInspirationCollection === "source-collection"
                    && activeInspirationFilter === "frame"
                    && inspirationSearchInput.value === "来源测试";

                  window.__sourceNeedsRelink = true;
                  await openInspirationSource(frameCard);
                  const relinkedAllLocalRecords = [...archiveFrames, ...archiveClips].every(
                    (record) => record.sourceFilePath === "/tmp/source-new.mov"
                  );

                  activeClipPlaybackEnd = 8;
                  activeClipPlaybackContinue = true;
                  const clipBoundaryResult = handleActiveClipPlaybackBoundary(8);

                  window.__inspirationSourceWorkflowResult = JSON.stringify({
                    returnButtonVisible,
                    openedWorkbench,
                    restoredState,
                    sourceOpenCalls: window.__sourceOpenCalls,
                    sourceRelinkCalls: window.__sourceRelinkCalls,
                    relinkedAllLocalRecords,
                    clipBoundaryResult,
                    clipBoundaryCleared: activeClipPlaybackEnd === null
                  });
                })();
                "STARTED";
                """
            ) { _, error in
                if let error {
                    fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                    self.finished = true
                    NSApp.terminate(nil)
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.readWorkflowResult()
                }
            }
        }
    }

    private func readWorkflowResult() {
        webView.evaluateJavaScript("window.__inspirationSourceWorkflowResult") { value, error in
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
                result["returnButtonVisible"] as? Bool == true,
                result["openedWorkbench"] as? Bool == true,
                result["restoredState"] as? Bool == true,
                result["sourceOpenCalls"] as? Int == 2,
                result["sourceRelinkCalls"] as? Int == 1,
                result["relinkedAllLocalRecords"] as? Bool == true,
                result["clipBoundaryResult"] as? String == "continue",
                result["clipBoundaryCleared"] as? Bool == true
            else {
                fputs(
                    "TEST_ERROR invalid inspiration source workflow \(value as? String ?? "nil")\n",
                    stderr
                )
                self.finished = true
                NSApp.terminate(nil)
                return
            }
            self.finished = true
            print("INSPIRATION_SOURCE_WORKFLOW_TEST_OK")
            NSApp.terminate(nil)
        }
    }
}

@main
struct InspirationSourceWorkflowTestRunner {
    private static let delegate = InspirationSourceWorkflowTest()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}
