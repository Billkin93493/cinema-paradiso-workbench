import Cocoa
import WebKit

final class ShotTimeFieldWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__testSavedAnalysis = null;
                window.__testProject = {
                  name: "出入点测试影片",
                  filePath: "/tmp/shot-time-field-test.mov",
                  fileUrl: "",
                  duration: 16,
                  updatedAt: new Date().toISOString(),
                  analysis: {
                    mode: "local",
                    cutPoints: [0, 4, 8, 16],
                    cutConfidence: { "shot-4000": 0.8, "shot-8000": 0.7 },
                    shotData: {
                      "shot-0": { size: "中景", angle: "平视", movement: "固定", note: "第一镜" },
                      "shot-4000": { size: "近景", angle: "平视", movement: "固定", note: "需要调整的镜头" },
                      "shot-8000": { size: "全景", angle: "平视", movement: "固定", note: "后一镜" }
                    },
                    representativeFrames: {}
                  }
                };
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [],
                  getArchiveClips: async () => [],
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

        webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 1280, height: 820),
            configuration: configuration
        )
        webView.navigationDelegate = self
        window = NSWindow(
            contentRect: NSRect(x: -2000, y: -2000, width: 1280, height: 820),
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
            (async () => {
              currentLocalProject = window.__testProject;
              manualAnalysis = window.__testProject.analysis;
              initializeManualAnalysis(16);
              selectedManualShotKey = "shot-4000";
              updateShotEditor(currentManualShot());
              renderManualShots();

              shotInInput.value = "00:00:05:00";
              shotInInput.dispatchEvent(new Event("change", { bubbles: true }));
              await new Promise((resolve) => setTimeout(resolve, 850));

              shotOutInput.value = "00:00:10:00";
              shotOutInput.dispatchEvent(new Event("change", { bubbles: true }));
              await new Promise((resolve) => setTimeout(resolve, 850));

              window.__shotTimeFieldResult = {
                cutPoints: manualAnalysis.cutPoints,
                selectedKey: selectedManualShotKey,
                inValue: shotInInput.value,
                outValue: shotOutInput.value,
                durationValue: shotDurationInput.value,
                selectedNote: manualAnalysis.shotData[selectedManualShotKey]?.note || "",
                nextNote: manualAnalysis.shotData["shot-10000"]?.note || "",
                savedCutPoints: window.__testSavedAnalysis?.cutPoints || [],
                savedSelectedNote: window.__testSavedAnalysis?.shotData?.[selectedManualShotKey]?.note || ""
              };
            })();
            """
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            webView.evaluateJavaScript(
                "JSON.stringify(window.__shotTimeFieldResult)"
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
                    fputs("TEST_ERROR invalid shot time field result: \(String(describing: value))\n", stderr)
                    self.finished = true
                    NSApp.terminate(nil)
                    return
                }

                self.finished = true
                print("SHOT_TIME_FIELD_WORKFLOW_TEST_OK")
                NSApp.terminate(nil)
            }
        }
    }

    private func isValid(_ result: [String: Any]) -> Bool {
        guard
            let cutPoints = result["cutPoints"] as? [Double],
            cutPoints.count == 4,
            abs(cutPoints[1] - 5.0) < 0.05,
            abs(cutPoints[2] - 10.0) < 0.05,
            result["selectedKey"] as? String == "shot-5000",
            result["inValue"] as? String == "00:00:05:00",
            result["outValue"] as? String == "00:00:10:00",
            result["durationValue"] as? String == "5.0 秒",
            result["selectedNote"] as? String == "需要调整的镜头",
            result["nextNote"] as? String == "后一镜",
            let savedCutPoints = result["savedCutPoints"] as? [Double],
            savedCutPoints.count == 4,
            abs(savedCutPoints[1] - 5.0) < 0.05,
            abs(savedCutPoints[2] - 10.0) < 0.05,
            result["savedSelectedNote"] as? String == "需要调整的镜头"
        else {
            return false
        }
        return true
    }
}

@main
struct ShotTimeFieldWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = ShotTimeFieldWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
