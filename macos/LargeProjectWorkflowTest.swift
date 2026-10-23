import Cocoa
import WebKit

final class LargeProjectWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false
    private var reportRenderedPages = 0
    private var reportRenderedKey = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "largeReportRendered")
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__largeSavedAnalysis = null;
                window.__largeSaveCount = 0;
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [],
                  getArchiveClips: async () => [],
                  getInspirationCollections: async () => [],
                  getInspirationMemberships: async () => [],
                  getInspirationNotes: async () => [],
                  saveAnalysis: async (analysis) => {
                    window.__largeSaveCount += 1;
                    window.__largeSavedAnalysis = JSON.parse(JSON.stringify(analysis));
                    return {
                      name: "两小时压力测试影片",
                      filePath: "/tmp/large-project-test.mov",
                      fileUrl: "",
                      duration: 7200,
                      analysis: window.__largeSavedAnalysis
                    };
                  }
                };
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.addEventListener("cinema-report-rendered", (event) => {
                  window.webkit?.messageHandlers?.largeReportRendered?.postMessage({
                    pages: event.detail?.pages?.length || 0,
                    key: event.detail?.pages?.[0]?.key || ""
                  });
                });
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 35) {
            if !self.finished {
                fputs("TEST_ERROR timeout\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.runWorkflow()
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard
            message.name == "largeReportRendered",
            let value = message.body as? [String: Any]
        else {
            return
        }
        reportRenderedPages = value["pages"] as? Int ?? 0
        reportRenderedKey = value["key"] as? String ?? ""
    }

    private func runWorkflow() {
        webView.evaluateJavaScript(
            """
            window.__largeProjectResult = null;
            (async () => {
              const shotCount = 1200;
              const duration = 7200;
              const cutPoints = Array.from(
                { length: shotCount + 1 },
                (_, index) => index * (duration / shotCount)
              );
              const shotData = {};
              for (let index = 0; index < shotCount; index += 1) {
                const key = `shot-${Math.round(cutPoints[index] * 1000)}`;
                shotData[key] = {
                  size: index % 4 === 0 ? "全景" : "中景",
                  angle: index % 7 === 0 ? "俯拍" : "平视",
                  movement: index % 5 === 0 ? "跟拍" : "固定",
                  note: index % 3 === 0 ? `压力测试导演笔记 ${index + 1}` : ""
                };
              }
              const project = {
                name: "两小时压力测试影片",
                filePath: "/tmp/large-project-test.mov",
                fileUrl: "",
                duration,
                analysis: {
                  mode: "manual",
                  cutPoints,
                  shotData,
                  cutConfidence: {},
                  representativeFrames: {}
                }
              };

              const renderStart = Date.now();
              applyLocalProject(project, true);
              const renderMs = Date.now() - renderStart;
              const initialCardCount = document.querySelectorAll(".manual-shot").length;

              const switchStart = Date.now();
              const targetShot = manualShots()[899];
              selectManualShot(targetShot.key, false);
              const switchMs = Date.now() - switchStart;
              directorNote.value = "第 900 镜异常中断前已保存的导演笔记";
              directorNote.dispatchEvent(new Event("input", { bubbles: true }));
              await new Promise((resolve) => setTimeout(resolve, 900));

              const saveBytes = new TextEncoder().encode(
                JSON.stringify(window.__largeSavedAnalysis)
              ).length;
              const reopenedProject = {
                ...project,
                analysis: JSON.parse(JSON.stringify(window.__largeSavedAnalysis))
              };
              const reopenStart = Date.now();
              applyLocalProject(reopenedProject, true);
              const reopenMs = Date.now() - reopenStart;
              const reopenedShots = manualShots();
              const reopenedNote = reopenedProject.analysis
                .shotData[targetShot.key]?.note || "";

              const reportStart = Date.now();
              const report = buildCurrentReportData();
              const reportBuildMs = Date.now() - reportStart;
              const reportBytes = new TextEncoder().encode(
                JSON.stringify(report)
              ).length;
              openPage("export");
              await new Promise((resolve) => setTimeout(resolve, 7000));
              const reportDocument = document.querySelector("#report-preview-frame")?.contentDocument;
              const renderedReportPages = reportDocument
                ?.querySelectorAll(".report-page[data-page-key]").length || 0;
              const reportStillWaiting = Boolean(
                reportDocument?.querySelector(".report-waiting")
              );

              window.__largeProjectResult = JSON.stringify({
                duration,
                expectedShots: shotCount,
                initialCardCount,
                reopenedShotCount: reopenedShots.length,
                renderMs,
                switchMs,
                reopenMs,
                reportBuildMs,
                saveCount: window.__largeSaveCount,
                saveBytes,
                reportBytes,
                reopenedNote,
                timelineSummary: document.querySelector("#timeline-summary")?.textContent || "",
                reportShotCount: report?.shots?.length || 0,
                reportPageLabel: document.querySelector("#export-page-count")?.textContent || "",
                renderedReportPages,
                reportStillWaiting,
                reportFrameSrc: document.querySelector("#report-preview-frame")?.src || "",
                reportDocumentURL: reportDocument?.URL || "",
                reportBodyText: reportDocument?.body?.innerText?.slice(0, 120) || "",
                scriptErrors: []
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
                self.readResult()
            }
        }
    }

    private func readResult() {
        webView.evaluateJavaScript("window.__largeProjectResult") { value, error in
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
                result["duration"] as? Int == 7200,
                result["expectedShots"] as? Int == 1200,
                result["initialCardCount"] as? Int == 1200,
                result["reopenedShotCount"] as? Int == 1200,
                result["reportShotCount"] as? Int == 1200,
                result["saveCount"] as? Int == 1,
                result["reopenedNote"] as? String == "第 900 镜异常中断前已保存的导演笔记",
                (result["timelineSummary"] as? String)?.contains("1200 个镜头") == true,
                result["reportPageLabel"] as? String == "302 页",
                (result["reportFrameSrc"] as? String)?.contains("preview=cover") == true,
                (result["reportFrameSrc"] as? String)?.contains("#data=") == false,
                self.reportRenderedPages == 1,
                self.reportRenderedKey == "cover"
            else {
                fputs(
                    "TEST_ERROR invalid large project workflow \(value as? String ?? "nil")\n",
                    stderr
                )
                self.finished = true
                NSApp.terminate(nil)
                return
            }
            self.finished = true
            print(json)
            NSApp.terminate(nil)
        }
    }
}

@main
struct LargeProjectWorkflowTestRunner {
    private static let delegate = LargeProjectWorkflowTest()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}
