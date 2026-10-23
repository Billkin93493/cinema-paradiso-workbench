import Cocoa
import WebKit

final class LargeArchiveWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                const projectNames = ["潮汐之后", "北岸来信", "无声旅馆", "雨夜归途"];
                window.__archiveFrames = Array.from({ length: 800 }, (_, index) => ({
                  id: `frame-${index}`,
                  projectName: projectNames[index % projectNames.length],
                  sourceFilePath: `/tmp/film-${index % projectNames.length}.mov`,
                  shotKey: `shot-${index}`,
                  shotNumber: index + 1,
                  start: index * 6,
                  end: index * 6 + 6,
                  capturedAt: index * 6 + 3,
                  imageUrl: "./assets/still-03.png",
                  note: index === 777 ? "关键导演笔记 777" : `静帧导演笔记 ${index}`,
                  tags: [index % 2 === 0 ? "日景" : "夜景", index % 3 === 0 ? "全景" : "中景"],
                  createdAt: new Date(Date.UTC(2026, 5, 14, 12, 0, 0) - index * 1000).toISOString()
                }));
                window.__archiveClips = Array.from({ length: 400 }, (_, index) => ({
                  id: `clip-${index}`,
                  type: "clip",
                  projectName: projectNames[index % projectNames.length],
                  sourceFilePath: `/tmp/film-${index % projectNames.length}.mov`,
                  shotKey: `shot-${index}`,
                  shotNumber: index + 1,
                  start: index * 8,
                  end: index * 8 + 5,
                  capturedAt: index * 8 + 2,
                  imageUrl: "./assets/still-07.png",
                  note: `片段导演笔记 ${index}`,
                  tags: [index % 2 === 0 ? "日景" : "夜景", "跟拍"],
                  createdAt: new Date(Date.UTC(2026, 5, 13, 12, 0, 0) - index * 1000).toISOString()
                }));

                function clone(value) {
                  return JSON.parse(JSON.stringify(value));
                }

                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => clone(window.__archiveFrames),
                  getArchiveClips: async () => clone(window.__archiveClips),
                  getInspirationCollections: async () => [],
                  getInspirationMemberships: async () => [],
                  getInspirationNotes: async () => [],
                  updateArchiveTags: async ({ items, mode, tags }) => {
                    const keys = new Set(items.map((item) => `${item.type}:${item.id}`));
                    const update = (record, type) => {
                      if (!keys.has(`${type}:${record.id}`)) return record;
                      if (mode === "remove") {
                        return { ...record, tags: record.tags.filter((tag) => !tags.includes(tag)) };
                      }
                      return { ...record, tags: [...new Set([...record.tags, ...tags])] };
                    };
                    window.__archiveFrames = window.__archiveFrames.map(
                      (record) => update(record, "frame")
                    );
                    window.__archiveClips = window.__archiveClips.map(
                      (record) => update(record, "clip")
                    );
                    return {
                      frames: clone(window.__archiveFrames),
                      clips: clone(window.__archiveClips)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if !self.finished {
                fputs("TEST_ERROR large archive timeout\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.runWorkflow()
        }
    }

    private func runWorkflow() {
        webView.evaluateJavaScript(
            """
            window.__largeArchiveResult = null;
            (async () => {
              const openStartedAt = performance.now();
              openPage("archive");
              await new Promise((resolve) => setTimeout(resolve, 500));
              const initialCount = document.querySelectorAll(".memory-card").length;
              const openMs = Math.round(performance.now() - openStartedAt);

              const searchStartedAt = performance.now();
              const searchInput = document.querySelector("#archive-search-input");
              searchInput.value = "关键导演笔记 777";
              searchInput.dispatchEvent(new Event("input", { bubbles: true }));
              const searchedIds = [...document.querySelectorAll(".memory-card")]
                .map((card) => card.dataset.recordId);
              const searchMs = Math.round(performance.now() - searchStartedAt);

              searchInput.value = "";
              searchInput.dispatchEvent(new Event("input", { bubbles: true }));
              const filterStartedAt = performance.now();
              document.querySelector('[data-filter="clip"]').click();
              activeArchiveProject = "/tmp/film-1.mov";
              activeArchiveTag = "夜景";
              renderArchiveFrames();
              const filteredCount = document.querySelectorAll(".memory-card").length;
              const filterMs = Math.round(performance.now() - filterStartedAt);

              document.querySelector("#archive-clear-filters").click();
              const organizeStartedAt = performance.now();
              document.querySelector("#archive-bulk-button").click();
              const cards = [...document.querySelectorAll(".memory-card")].slice(0, 20);
              cards.forEach((card) => card.click());
              document.querySelector("#archive-bulk-tag-input").value = "长片压力测试";
              document.querySelector("#archive-bulk-add-tag").click();
              await new Promise((resolve) => setTimeout(resolve, 250));
              const organizedIds = new Set(cards.map((card) => card.dataset.recordId));
              const organizedCount = [
                ...window.__archiveFrames,
                ...window.__archiveClips
              ].filter((record) => (
                organizedIds.has(record.id) && record.tags.includes("长片压力测试")
              )).length;
              const organizeMs = Math.round(performance.now() - organizeStartedAt);

              window.__largeArchiveResult = JSON.stringify({
                initialCount,
                openMs,
                searchedIds,
                searchMs,
                filteredCount,
                filterMs,
                organizedCount,
                organizeMs,
                selectedCount: document.querySelector("#archive-selected-count").textContent
              });
            })();
            "STARTED";
            """
        ) { _, error in
            if let error {
                fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                self.finish()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.readResult()
            }
        }
    }

    private func readResult() {
        webView.evaluateJavaScript("window.__largeArchiveResult") { value, error in
            if let error {
                fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                self.finish()
                return
            }
            guard
                let json = value as? String,
                let data = json.data(using: .utf8),
                let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                result["initialCount"] as? Int == 1200,
                result["searchedIds"] as? [String] == ["frame-777"],
                result["filteredCount"] as? Int == 100,
                result["organizedCount"] as? Int == 20,
                result["selectedCount"] as? String == "已选择 20 项"
            else {
                fputs(
                    "TEST_ERROR invalid large archive workflow \(value as? String ?? "nil")\n",
                    stderr
                )
                self.finish()
                return
            }
            print(json)
            self.finish()
        }
    }

    private func finish() {
        finished = true
        NSApp.terminate(nil)
    }
}

@main
struct LargeArchiveWorkflowTestRunner {
    private static let delegate = LargeArchiveWorkflowTest()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}
