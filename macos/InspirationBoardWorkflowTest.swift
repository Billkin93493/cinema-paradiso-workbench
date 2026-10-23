import Cocoa
import WebKit

final class InspirationBoardWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__testInspirationNotes = [];
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [{
                    id: "frame-board-test",
                    projectName: "灵感测试影片",
                    sourceFilePath: "/tmp/inspiration-board.mov",
                    shotKey: "shot-1",
                    shotNumber: 1,
                    start: 0,
                    end: 4,
                    capturedAt: 2,
                    imageUrl: "./assets/still-05.png",
                    note: "测试静帧导演笔记",
                    tags: ["中景", "平视", "固定"],
                    createdAt: "2026-06-14T10:00:00.000Z"
                  }],
                  getArchiveClips: async () => [{
                    id: "clip-board-test",
                    projectName: "灵感测试影片",
                    sourceFilePath: "/tmp/inspiration-board.mov",
                    shotKey: "shot-2",
                    shotNumber: 2,
                    start: 4,
                    end: 10,
                    capturedAt: 6,
                    imageUrl: "./assets/still-07.png",
                    note: "测试片段导演笔记",
                    tags: ["近景", "侧面", "固定"],
                    createdAt: "2026-06-14T09:00:00.000Z"
                  }],
                  getInspirationCollections: async () => [{
                    id: "collection-board-test",
                    name: "测试收藏夹",
                    description: "检查真实瀑布流和文字卡片保存。",
                    createdAt: "2026-06-14T08:00:00.000Z",
                    updatedAt: "2026-06-14T08:00:00.000Z",
                    lastUsedAt: "2026-06-14T08:00:00.000Z"
                  }],
                  getInspirationMemberships: async () => [
                    {
                      id: "membership-frame",
                      collectionId: "collection-board-test",
                      itemType: "frame",
                      itemId: "frame-board-test",
                      addedAt: "2026-06-14T10:00:00.000Z"
                    },
                    {
                      id: "membership-clip",
                      collectionId: "collection-board-test",
                      itemType: "clip",
                      itemId: "clip-board-test",
                      addedAt: "2026-06-14T09:00:00.000Z"
                    }
                  ],
                  getInspirationNotes: async () => (
                    JSON.parse(JSON.stringify(window.__testInspirationNotes))
                  ),
                  upsertInspirationNote: async (payload) => {
                    const now = new Date().toISOString();
                    const index = window.__testInspirationNotes.findIndex(
                      (note) => note.id === payload.id
                    );
                    const record = {
                      id: index >= 0 ? payload.id : "note-board-test",
                      title: payload.title.trim() || "未命名文字",
                      body: payload.body.trim(),
                      collectionIds: [...payload.collectionIds],
                      createdAt: index >= 0
                        ? window.__testInspirationNotes[index].createdAt
                        : now,
                      updatedAt: now
                    };
                    if (index >= 0) {
                      window.__testInspirationNotes[index] = record;
                    } else {
                      window.__testInspirationNotes.push(record);
                    }
                    return JSON.parse(JSON.stringify(record));
                  },
                  touchInspirationCollection: async () => null
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
                window.__inspirationBoardWorkflowResult = null;
                (async () => {
                  openPage("inspiration");
                  await loadInspirationCollections();
                  const initialRealCards = document.querySelectorAll(
                    '[data-real-inspiration="true"]'
                  ).length;

                  openInspirationNoteEditor();
                  noteTitleInput.value = "雨夜人物停顿";
                  noteTitleInput.dispatchEvent(new Event("input", { bubbles: true }));
                  noteBodyInput.value = "让环境继续运动，人物停在画面中心。";
                  noteBodyInput.dispatchEvent(new Event("input", { bubbles: true }));
                  const collectionCheckbox = noteCollectionOptions.querySelector(
                    'input[value="collection-board-test"]'
                  );
                  collectionCheckbox.checked = true;
                  collectionCheckbox.dispatchEvent(new Event("change", { bubbles: true }));
                  await new Promise((resolve) => setTimeout(resolve, 700));
                  await noteSaveQueue;

                  inspirationNotes = [];
                  await loadInspirationCollections();
                  selectInspirationCollection("collection-board-test", { touch: false });
                  const collectionCount = document.querySelector(
                    '[data-collection="collection-board-test"] small'
                  )?.textContent;
                  const textCard = document.querySelector(
                    '[data-real-inspiration="true"][data-inspiration-type="text"]'
                  );
                  selectInspirationFilter("text");
                  const visibleTextCards = [...document.querySelectorAll(
                    '[data-real-inspiration="true"][data-inspiration-type="text"]'
                  )].filter((card) => !card.hidden).length;

                  window.__inspirationBoardWorkflowResult = JSON.stringify({
                    initialRealCards,
                    savedNoteCount: window.__testInspirationNotes.length,
                    realCardsAfterReload: document.querySelectorAll(
                      '[data-real-inspiration="true"]'
                    ).length,
                    textCardTitle: textCard?.querySelector("h4")?.textContent || "",
                    collectionCount,
                    visibleTextCards,
                    noteSaveState: noteSaveState?.textContent || ""
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
        webView.evaluateJavaScript("window.__inspirationBoardWorkflowResult") { value, error in
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
                result["initialRealCards"] as? Int == 2,
                result["savedNoteCount"] as? Int == 1,
                result["realCardsAfterReload"] as? Int == 3,
                result["textCardTitle"] as? String == "雨夜人物停顿",
                result["collectionCount"] as? String == "3 项资料",
                result["visibleTextCards"] as? Int == 1,
                (result["noteSaveState"] as? String)?.contains("已自动保存") == true
            else {
                fputs(
                    "TEST_ERROR invalid inspiration board workflow \(value as? String ?? "nil")\n",
                    stderr
                )
                self.finished = true
                NSApp.terminate(nil)
                return
            }
            self.finished = true
            print("INSPIRATION_BOARD_WORKFLOW_TEST_OK")
            NSApp.terminate(nil)
        }
    }
}

@main
struct InspirationBoardWorkflowTestRunner {
    private static let delegate = InspirationBoardWorkflowTest()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}
