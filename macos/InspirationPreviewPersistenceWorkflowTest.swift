import Cocoa
import WebKit

final class InspirationPreviewPersistenceWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__testFrames = [{
                  id: "frame-preview-test",
                  projectName: "预览保存测试影片",
                  sourceFilePath: "/tmp/inspiration-preview.mov",
                  shotKey: "shot-1",
                  shotNumber: 1,
                  start: 0,
                  end: 4,
                  capturedAt: 2,
                  imageUrl: "./assets/still-05.png",
                  note: "原导演笔记",
                  tags: ["中景", "固定"],
                  createdAt: "2026-06-15T08:00:00.000Z"
                }];
                window.__testMemberships = [{
                  id: "membership-a",
                  collectionId: "collection-a",
                  itemType: "frame",
                  itemId: "frame-preview-test",
                  addedAt: "2026-06-15T08:00:00.000Z"
                }];
                window.__testNoteWriteCount = 0;
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => JSON.parse(JSON.stringify(window.__testFrames)),
                  getArchiveClips: async () => [],
                  getInspirationCollections: async () => [
                    {
                      id: "collection-a",
                      name: "收藏夹 A",
                      description: "当前收藏夹",
                      createdAt: "2026-06-15T07:00:00.000Z",
                      updatedAt: "2026-06-15T07:00:00.000Z",
                      lastUsedAt: "2026-06-15T07:00:00.000Z"
                    },
                    {
                      id: "collection-b",
                      name: "收藏夹 B",
                      description: "跨收藏夹管理",
                      createdAt: "2026-06-15T06:00:00.000Z",
                      updatedAt: "2026-06-15T06:00:00.000Z",
                      lastUsedAt: "2026-06-15T06:00:00.000Z"
                    }
                  ],
                  getInspirationMemberships: async () => (
                    JSON.parse(JSON.stringify(window.__testMemberships))
                  ),
                  getInspirationNotes: async () => [],
                  touchInspirationCollection: async () => null,
                  updateArchiveNote: async (payload) => {
                    const record = window.__testFrames.find((item) => item.id === payload.itemId);
                    if (!record) return { error: "没有找到测试资料" };
                    record.note = payload.note;
                    window.__testNoteWriteCount += 1;
                    return {
                      frames: JSON.parse(JSON.stringify(window.__testFrames)),
                      clips: []
                    };
                  },
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
                    return JSON.parse(JSON.stringify(membership));
                  },
                  removeArchiveFromInspiration: async (payload) => {
                    const before = window.__testMemberships.length;
                    window.__testMemberships = window.__testMemberships.filter((item) => !(
                      item.collectionId === payload.collectionId
                      && item.itemType === payload.itemType
                      && item.itemId === payload.itemId
                    ));
                    return {
                      removed: before - window.__testMemberships.length,
                      collectionId: payload.collectionId
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
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
                window.__inspirationPreviewPersistenceResult = null;
                (async () => {
                  openPage("inspiration");
                  await loadInspirationCollections();
                  selectInspirationCollection("collection-a", { touch: false });

                  let card = document.querySelector(
                    '[data-real-inspiration="true"][data-inspiration-type="frame"]'
                  );
                  openInspirationPreview(card);
                  inspirationPreviewNote.value = "关闭弹窗后仍然保留的新笔记";
                  inspirationPreviewNote.dispatchEvent(new Event("input", { bubbles: true }));
                  closeInspirationPreview();
                  await inspirationPreviewNoteSaveQueue;

                  await loadInspirationCollections();
                  selectInspirationCollection("collection-a", { touch: false });
                  card = document.querySelector(
                    '[data-real-inspiration="true"][data-inspiration-type="frame"]'
                  );
                  openInspirationPreview(card);
                  const noteAfterReload = inspirationPreviewNote.value;

                  const checkboxB = inspirationPreviewCollectionList.querySelector(
                    'input[data-collection-id="collection-b"]'
                  );
                  checkboxB.checked = true;
                  checkboxB.dispatchEvent(new Event("change", { bubbles: true }));
                  await new Promise((resolve) => setTimeout(resolve, 120));
                  const countAfterAdd = window.__testMemberships.length;

                  checkboxB.checked = false;
                  checkboxB.dispatchEvent(new Event("change", { bubbles: true }));
                  await new Promise((resolve) => setTimeout(resolve, 120));
                  const countAfterCancel = window.__testMemberships.length;

                  inspirationRemoveCard.click();
                  await new Promise((resolve) => setTimeout(resolve, 120));

                  window.__inspirationPreviewPersistenceResult = JSON.stringify({
                    noteAfterReload,
                    storedNote: window.__testFrames[0].note,
                    noteWriteCount: window.__testNoteWriteCount,
                    countAfterAdd,
                    countAfterCancel,
                    finalMembershipCount: window.__testMemberships.length,
                    frameStillInArchive: window.__testFrames.length === 1,
                    previewClosed: inspirationPreviewOverlay.hidden
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
        webView.evaluateJavaScript("window.__inspirationPreviewPersistenceResult") { value, error in
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
                result["noteAfterReload"] as? String == "关闭弹窗后仍然保留的新笔记",
                result["storedNote"] as? String == "关闭弹窗后仍然保留的新笔记",
                result["noteWriteCount"] as? Int == 1,
                result["countAfterAdd"] as? Int == 2,
                result["countAfterCancel"] as? Int == 1,
                result["finalMembershipCount"] as? Int == 0,
                result["frameStillInArchive"] as? Bool == true,
                result["previewClosed"] as? Bool == true
            else {
                fputs(
                    "TEST_ERROR invalid inspiration preview persistence workflow \(value as? String ?? "nil")\n",
                    stderr
                )
                self.finished = true
                NSApp.terminate(nil)
                return
            }
            self.finished = true
            print("INSPIRATION_PREVIEW_PERSISTENCE_WORKFLOW_TEST_OK")
            NSApp.terminate(nil)
        }
    }
}

@main
struct InspirationPreviewPersistenceWorkflowTestRunner {
    private static let delegate = InspirationPreviewPersistenceWorkflowTest()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}
