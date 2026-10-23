import Cocoa
import WebKit

final class DeleteCutWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
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
                window.__savedAnalysis = null;
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [],
                  getArchiveClips: async () => [],
                  updateProject: async (updates) => ({
                    name: "删除切点测试影片",
                    filePath: "",
                    fileUrl: window.__testVideoUrl,
                    duration: updates.duration || 0,
                    analysis: window.__savedAnalysis
                  }),
                  saveAnalysis: async (analysis) => {
                    window.__savedAnalysis = JSON.parse(JSON.stringify(analysis));
                    return {
                      name: "删除切点测试影片",
                      filePath: "",
                      fileUrl: window.__testVideoUrl,
                      duration: document.querySelector("#local-video")?.duration || 0,
                      analysis: window.__savedAnalysis
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
        let videoURL = URL(
            fileURLWithPath: "/System/Library/CoreServices/ControlCenter.app/Contents/Resources/BentoGalleryIntroduction.mov"
        ).absoluteString
        let videoJSON = String(
            data: try! JSONSerialization.data(
                withJSONObject: videoURL,
                options: [.fragmentsAllowed]
            ),
            encoding: .utf8
        )!
        webView.evaluateJavaScript(
            """
            window.__testVideoUrl = \(videoJSON);
            const project = {
              name: "删除切点测试影片",
              filePath: "",
              fileUrl: window.__testVideoUrl,
              duration: 16.013,
              analysis: {
                mode: "manual",
                cutPoints: [0, 4, 8, 16.013],
                cutConfidence: {},
                shotData: {
                  "shot-0": { size: "中景", angle: "平视", movement: "固定", note: "前一镜笔记" },
                  "shot-4000": { size: "近景", angle: "平视", movement: "固定", note: "后一镜笔记" },
                  "shot-8000": { size: "全景", angle: "平视", movement: "固定", note: "" }
                }
              }
            };
            applyLocalProject(project, true);
            selectManualShot("shot-4000", false);
            deleteSelectedCutPoint();
            """
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            webView.evaluateJavaScript(
                """
                JSON.stringify({
                  cutPoints: window.__savedAnalysis?.cutPoints,
                  shotCount: document.querySelectorAll(".manual-shot").length,
                  selectedKey: selectedManualShotKey,
                  mergedNote: window.__savedAnalysis?.shotData?.["shot-0"]?.note,
                  removedShot: window.__savedAnalysis?.shotData?.["shot-4000"] === undefined,
                  buttonLabel: document.querySelector('[data-action="delete-cut"]')?.textContent.trim(),
                  toast: document.querySelector(".toast")?.textContent
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
struct DeleteCutWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = DeleteCutWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
