import Cocoa
import WebKit

final class ArchiveOrganizationWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__archiveFrames = [
                  {
                    id: "frame-b",
                    projectName: "北岸来信",
                    sourceFilePath: "/tmp/north.mov",
                    shotKey: "shot-5",
                    shotNumber: 5,
                    start: 20,
                    end: 25,
                    capturedAt: 22,
                    imageUrl: "./assets/still-05.png",
                    note: "雨中的人物等待",
                    tags: ["中景", "夜景"],
                    createdAt: "2026-06-14T12:00:00.000Z"
                  },
                  {
                    id: "frame-a",
                    projectName: "潮汐之后",
                    sourceFilePath: "/tmp/tide.mov",
                    shotKey: "shot-8",
                    shotNumber: 8,
                    start: 30,
                    end: 36,
                    capturedAt: 33,
                    imageUrl: "./assets/still-03.png",
                    note: "窗边自然光",
                    tags: ["全景", "日景"],
                    createdAt: "2026-06-14T10:00:00.000Z"
                  }
                ];
                window.__archiveClips = [
                  {
                    id: "clip-a",
                    type: "clip",
                    projectName: "潮汐之后",
                    sourceFilePath: "/tmp/tide.mov",
                    shotKey: "shot-2",
                    shotNumber: 2,
                    start: 5,
                    end: 12,
                    capturedAt: 8,
                    imageUrl: "./assets/still-07.png",
                    note: "夜景跟拍",
                    tags: ["近景", "夜景"],
                    createdAt: "2026-06-14T11:00:00.000Z"
                  }
                ];

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
                      if (mode === "replace") return { ...record, tags: [...tags] };
                      if (mode === "remove") {
                        return {
                          ...record,
                          tags: record.tags.filter((tag) => !tags.includes(tag))
                        };
                      }
                      return {
                        ...record,
                        tags: [...new Set([...record.tags, ...tags])]
                      };
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            if !self.finished {
                fputs("TEST_ERROR timeout\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.webView.evaluateJavaScript(
                """
                window.__archiveOrganizationResult = null;
                (async () => {
                  openPage("archive");
                  await new Promise((resolve) => setTimeout(resolve, 150));

                  document.querySelector('[data-filter="clip"]').click();
                  activeArchiveProject = "/tmp/tide.mov";
                  activeArchiveTag = "夜景";
                  renderArchiveFrames();
                  const combinedFilterIds = [...document.querySelectorAll(".memory-card")]
                    .map((card) => card.dataset.recordId);

                  document.querySelector("#archive-clear-filters").click();
                  archiveSortMode = "shot";
                  renderArchiveFrames();
                  const shotOrder = [...document.querySelectorAll(".memory-card")]
                    .map((card) => card.dataset.recordId);

                  document.querySelector('[data-record-id="frame-a"]').click();
                  const commonIndoor = [...document.querySelectorAll("#archive-common-tags button")]
                    .find((button) => button.textContent === "室内");
                  commonIndoor.click();
                  document.querySelector("#archive-custom-tag-input").value = "低照度";
                  document.querySelector("#archive-add-custom-tag").click();
                  const dayTag = [...document.querySelectorAll("#archive-current-tags button")]
                    .find((button) => button.textContent === "日景");
                  dayTag.click();
                  document.querySelector("#archive-save-tags").click();
                  await new Promise((resolve) => setTimeout(resolve, 120));

                  document.querySelector("#archive-bulk-button").click();
                  document.querySelector('[data-record-id="frame-b"]').click();
                  document.querySelector('[data-record-id="clip-a"]').click();
                  document.querySelector("#archive-bulk-tag-input").value = "雨夜";
                  document.querySelector("#archive-bulk-add-tag").click();
                  await new Promise((resolve) => setTimeout(resolve, 120));
                  document.querySelector("#archive-bulk-tag-input").value = "夜景";
                  document.querySelector("#archive-bulk-remove-tag").click();
                  await new Promise((resolve) => setTimeout(resolve, 120));

                  const updatedFrameA = window.__archiveFrames.find(
                    (record) => record.id === "frame-a"
                  );
                  const updatedFrameB = window.__archiveFrames.find(
                    (record) => record.id === "frame-b"
                  );
                  const updatedClipA = window.__archiveClips.find(
                    (record) => record.id === "clip-a"
                  );
                  window.__archiveOrganizationResult = JSON.stringify({
                    combinedFilterIds,
                    shotOrder,
                    frameATags: updatedFrameA.tags,
                    frameBTags: updatedFrameB.tags,
                    clipATags: updatedClipA.tags,
                    selectedCount: document.querySelector("#archive-selected-count").textContent
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.readResult()
                }
            }
        }
    }

    private func readResult() {
        webView.evaluateJavaScript("window.__archiveOrganizationResult") { value, error in
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
                result["combinedFilterIds"] as? [String] == ["clip-a"],
                result["shotOrder"] as? [String] == ["frame-b", "clip-a", "frame-a"],
                Set(result["frameATags"] as? [String] ?? []) == Set(["全景", "室内", "低照度"]),
                Set(result["frameBTags"] as? [String] ?? []) == Set(["中景", "雨夜"]),
                Set(result["clipATags"] as? [String] ?? []) == Set(["近景", "雨夜"]),
                result["selectedCount"] as? String == "已选择 2 项"
            else {
                fputs(
                    "TEST_ERROR invalid archive organization workflow \(value as? String ?? "nil")\n",
                    stderr
                )
                self.finished = true
                NSApp.terminate(nil)
                return
            }
            self.finished = true
            print("ARCHIVE_ORGANIZATION_WORKFLOW_TEST_OK")
            NSApp.terminate(nil)
        }
    }
}

@main
struct ArchiveOrganizationWorkflowTestRunner {
    private static let delegate = ArchiveOrganizationWorkflowTest()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}
