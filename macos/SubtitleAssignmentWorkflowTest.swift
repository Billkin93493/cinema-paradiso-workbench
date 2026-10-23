import Cocoa
import WebKit

final class SubtitleAssignmentWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [],
                  getArchiveClips: async () => []
                };
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 1200, height: 800),
            configuration: configuration
        )
        webView.navigationDelegate = self
        window = NSWindow(
            contentRect: NSRect(x: -2000, y: -2000, width: 1200, height: 800),
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
        webView.evaluateJavaScript(
            """
            manualAnalysis = {
              mode: "manual",
              cutPoints: [0, 4, 8, 16],
              shotData: {},
              cutConfidence: {},
              representativeFrames: {},
              subtitles: {
                found: true,
                sourceName: "测试影片.zh-CN.srt",
                language: "zh-CN",
                cues: [
                  { start: 0.5, end: 1, text: "第一句" },
                  { start: 3, end: 5, text: "跨越切点" },
                  { start: 7.5, end: 8, text: "在切点结束" },
                  { start: 8, end: 9, text: "在切点开始" },
                  { start: 15.5, end: 17, text: "延伸到片尾外" },
                  { start: 16, end: 18, text: "从片尾开始" },
                  { start: 9, end: 9, text: "无效时间" },
                  { start: 10, end: 11, text: "   " }
                ]
              }
            };
            initializeManualAnalysis(16);
            const initial = JSON.parse(JSON.stringify(manualAnalysis.subtitleAssignments));

            manualAnalysis.cutPoints.push(6);
            initializeManualAnalysis(16);
            const afterAdd = JSON.parse(JSON.stringify(manualAnalysis.subtitleAssignments));

            manualAnalysis.cutPoints[1] = 5;
            initializeManualAnalysis(16);
            const afterMove = JSON.parse(JSON.stringify(manualAnalysis.subtitleAssignments));

            manualAnalysis.cutPoints.splice(1, 1);
            initializeManualAnalysis(16);
            const afterDelete = JSON.parse(JSON.stringify(manualAnalysis.subtitleAssignments));

            const noSubtitle = buildSubtitleAssignments(
              [{ key: "shot-0", index: 0, start: 0, end: 4 }],
              null
            );

            JSON.stringify({ initial, afterAdd, afterMove, afterDelete, noSubtitle });
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
                self.isValid(result)
            else {
                fputs("TEST_ERROR invalid subtitle assignments\n", stderr)
                self.finished = true
                NSApp.terminate(nil)
                return
            }

            self.finished = true
            print("SUBTITLE_ASSIGNMENT_TEST_OK")
            NSApp.terminate(nil)
        }
    }

    private func isValid(_ result: [String: Any]) -> Bool {
        guard
            let initial = result["initial"] as? [String: Any],
            let initialShots = initial["byShot"] as? [String: Any],
            initial["assignedCueCount"] as? Int == 6,
            cueCount(initialShots, key: "shot-0") == 2,
            cueCount(initialShots, key: "shot-4000") == 2,
            cueCount(initialShots, key: "shot-8000") == 2,
            let afterAdd = result["afterAdd"] as? [String: Any],
            let addShots = afterAdd["byShot"] as? [String: Any],
            cueCount(addShots, key: "shot-4000") == 1,
            cueCount(addShots, key: "shot-6000") == 1,
            let afterMove = result["afterMove"] as? [String: Any],
            let moveShots = afterMove["byShot"] as? [String: Any],
            cueCount(moveShots, key: "shot-0") == 2,
            cueCount(moveShots, key: "shot-5000") == 0,
            cueCount(moveShots, key: "shot-6000") == 1,
            let afterDelete = result["afterDelete"] as? [String: Any],
            let deleteShots = afterDelete["byShot"] as? [String: Any],
            cueCount(deleteShots, key: "shot-0") == 2,
            let noSubtitle = result["noSubtitle"] as? [String: Any],
            noSubtitle["assignedCueCount"] as? Int == 0,
            (noSubtitle["byShot"] as? [String: Any])?.isEmpty == true
        else {
            return false
        }
        return true
    }

    private func cueCount(_ shots: [String: Any], key: String) -> Int {
        guard
            let shot = shots[key] as? [String: Any],
            let cues = shot["cues"] as? [Any]
        else {
            return 0
        }
        return cues.count
    }
}

@main
struct SubtitleAssignmentWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = SubtitleAssignmentWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
