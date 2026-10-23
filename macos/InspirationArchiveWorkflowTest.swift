import Cocoa
import WebKit

final class InspirationArchiveWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__testMemberships = [];
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [{
                    id: "frame-test",
                    projectName: "拖拽测试影片",
                    sourceFilePath: "/tmp/drag-test.mov",
                    shotKey: "shot-1",
                    shotNumber: 1,
                    start: 0,
                    end: 4,
                    capturedAt: 2,
                    imageUrl: "./assets/still-05.png",
                    note: "拖拽测试静帧",
                    tags: ["中景", "平视", "固定"],
                    createdAt: "2026-06-14T10:00:00.000Z"
                  }],
                  getArchiveClips: async () => [{
                    id: "clip-test",
                    projectName: "拖拽测试影片",
                    sourceFilePath: "/tmp/drag-test.mov",
                    shotKey: "shot-2",
                    shotNumber: 2,
                    start: 4,
                    end: 10,
                    capturedAt: 6,
                    imageUrl: "./assets/still-07.png",
                    note: "拖拽测试片段",
                    tags: ["近景", "侧面", "固定"],
                    createdAt: "2026-06-14T09:00:00.000Z"
                  }],
                  getInspirationCollections: async () => [
                    {
                      id: "collection-a",
                      name: "收藏夹 A",
                      description: "第一个测试收藏夹",
                      createdAt: "2026-06-14T08:00:00.000Z",
                      updatedAt: "2026-06-14T08:00:00.000Z",
                      lastUsedAt: "2026-06-14T08:00:00.000Z"
                    },
                    {
                      id: "collection-b",
                      name: "收藏夹 B",
                      description: "第二个测试收藏夹",
                      createdAt: "2026-06-14T07:00:00.000Z",
                      updatedAt: "2026-06-14T07:00:00.000Z",
                      lastUsedAt: "2026-06-14T07:00:00.000Z"
                    }
                  ],
                  getInspirationMemberships: async () => (
                    JSON.parse(JSON.stringify(window.__testMemberships))
                  ),
                  addArchiveRecordToInspiration: async (payload) => {
                    const existing = window.__testMemberships.find((item) => (
                      item.collectionId === payload.collectionId
                      && item.itemType === payload.itemType
                      && item.itemId === payload.itemId
                    ));
                    if (existing) return { ...existing, alreadyExists: true };
                    const membership = {
                      id: `membership-${window.__testMemberships.length + 1}`,
                      ...payload,
                      addedAt: new Date().toISOString()
                    };
                    window.__testMemberships.push(membership);
                    return membership;
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
                openPage("archive");
                const card = document.querySelector(
                  '.memory-card[data-type="frame"][data-record-id="frame-test"]'
                );
                const record = { ...archiveFrames[0], type: "frame" };

                async function dropInto(collectionId) {
                  draggedArchiveRecord = record;
                  renderArchiveDropTargets();
                  const target = document.querySelector(
                    `[data-drop-collection="${collectionId}"]`
                  );
                  target.dispatchEvent(new Event("drop", {
                    bubbles: true,
                    cancelable: true
                  }));
                  await new Promise((resolve) => setTimeout(resolve, 80));
                }

                window.__inspirationArchiveWorkflowResult = null;
                (async () => {
                  await dropInto("collection-a");
                  await dropInto("collection-a");
                  const duplicateMessage = document.querySelector(".toast")?.textContent || "";
                  await dropInto("collection-b");
                  inspirationMemberships = [];
                  await loadInspirationCollections();
                  renderArchiveDropTargets();
                  const countA = document.querySelector(
                    '[data-collection="collection-a"] small'
                  )?.textContent;
                  const countB = document.querySelector(
                    '[data-collection="collection-b"] small'
                  )?.textContent;
                  window.__inspirationArchiveWorkflowResult = JSON.stringify({
                    draggableCards: document.querySelectorAll(
                      '.memory-card[draggable="true"]'
                    ).length,
                    dropTargets: document.querySelectorAll(
                      ".archive-drop-target"
                    ).length,
                    membershipCount: inspirationMemberships.length,
                    collectionACount: countA,
                    collectionBCount: countB,
                    duplicateMessage,
                    storedMembershipCount: window.__testMemberships.length,
                    frameStillInArchive: Boolean(card)
                  });
                })();
                "STARTED";
                """
            ) { value, error in
                if let error {
                    fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                    self.finished = true
                    NSApp.terminate(nil)
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.readWorkflowResult()
                }
            }
        }
    }

    private func readWorkflowResult() {
        webView.evaluateJavaScript("window.__inspirationArchiveWorkflowResult") { value, error in
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
                result["draggableCards"] as? Int == 2,
                result["dropTargets"] as? Int == 2,
                result["membershipCount"] as? Int == 2,
                result["storedMembershipCount"] as? Int == 2,
                result["collectionACount"] as? String == "1 项资料",
                result["collectionBCount"] as? String == "1 项资料",
                (result["duplicateMessage"] as? String)?.contains("已经在") == true,
                result["frameStillInArchive"] as? Bool == true
            else {
                fputs(
                    "TEST_ERROR invalid inspiration archive workflow \(value as? String ?? "nil")\n",
                    stderr
                )
                self.finished = true
                NSApp.terminate(nil)
                return
            }
            self.finished = true
            print("INSPIRATION_ARCHIVE_WORKFLOW_TEST_OK")
            NSApp.terminate(nil)
        }
    }
}

@main
struct InspirationArchiveWorkflowTestRunner {
    private static let delegate = InspirationArchiveWorkflowTest()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}
