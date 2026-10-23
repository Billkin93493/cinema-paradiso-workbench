import Cocoa
import WebKit

final class BasicSceneWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__savedAnalysis = null;
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [],
                  getArchiveClips: async () => [],
                  saveAnalysis: async (analysis) => {
                    window.__savedAnalysis = JSON.parse(JSON.stringify(analysis));
                    return {
                      name: "基础识别测试影片",
                      filePath: "/tmp/basic-scene-test.mov",
                      fileUrl: "",
                      duration: 8,
                      analysis: window.__savedAnalysis
                    };
                  },
                  generateRepresentativeFrames: async () => ({}),
                  analyzeBasicScenes: async (frames, onProgress) => {
                    onProgress?.({ percent: 100 });
                    return Object.fromEntries(frames.map((frame, index) => [
                      frame.shotKey,
                      {
                        shotKey: frame.shotKey,
                        people: {
                          value: index === 0 ? "双人" : "单人",
                          confidence: 0.86,
                          source: "auto"
                        },
                        timeOfDay: {
                          value: "日景",
                          confidence: 0.72,
                          source: "auto"
                        },
                        setting: {
                          value: index === 0 ? "室外" : "室内",
                          confidence: 0.68,
                          source: "auto"
                        }
                      }
                    ]));
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
        webView.evaluateJavaScript(
            """
            openPage("workbench");
            currentLocalProject = {
              name: "基础识别测试影片",
              filePath: "/tmp/basic-scene-test.mov",
              fileUrl: "",
              duration: 8
            };
            manualAnalysis = {
              mode: "local",
              cutPoints: [0, 4, 8],
              cutConfidence: {},
              shotData: {},
              representativeFrames: {
                "shot-0": {
                  shotKey: "shot-0",
                  capturedAt: 2,
                  imageUrl: "file:///tmp/shot-0.jpg",
                  source: "auto"
                },
                "shot-4000": {
                  shotKey: "shot-4000",
                  capturedAt: 6,
                  imageUrl: "file:///tmp/shot-4000.jpg",
                  source: "auto"
                }
              }
            };
            initializeManualAnalysis(8);
            selectedManualShotKey = "shot-0";
            updateShotEditor(manualShots()[0]);
            renderManualShots();
            setWorkbenchSideTab("basic");
            analyzeBasicScenes();
            """
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.webView.evaluateJavaScript(
                """
                const firstResult = manualAnalysis.basicSceneAnalysis.byShot["shot-0"];
                const indoorButton = basicScenePanel.querySelector(
                  '[data-basic-field="setting"][data-basic-value="室内"]'
                );
                indoorButton.click();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            self.webView.evaluateJavaScript(
                """
                analyzeBasicScenes();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            self.webView.evaluateJavaScript(
                """
                const first = manualAnalysis.basicSceneAnalysis.byShot["shot-0"];
                selectManualShot("shot-4000", false);
                const second = manualAnalysis.basicSceneAnalysis.byShot["shot-4000"];
                JSON.stringify({
                  tabActive: basicSceneTab.classList.contains("active"),
                  panelVisible: !basicScenePanel.hidden,
                  analysisHidden: directorAnalysisPanel.hidden,
                  firstPeople: first.people.value,
                  firstSetting: first.setting.value,
                  firstSettingSource: first.setting.source,
                  secondPeople: second.people.value,
                  secondSetting: second.setting.value,
                  selectedSecond: basicScenePanel.querySelector(
                    '[data-basic-field="setting"][data-basic-value="室内"]'
                  ).classList.contains("selected"),
                  saved: window.__savedAnalysis?.basicSceneAnalysis?.byShot?.["shot-0"]?.setting?.value,
                  saveState: basicSceneSaveState.textContent
                });
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
                    result["tabActive"] as? Bool == true,
                    result["panelVisible"] as? Bool == true,
                    result["analysisHidden"] as? Bool == true,
                    result["firstPeople"] as? String == "双人",
                    result["firstSetting"] as? String == "室内",
                    result["firstSettingSource"] as? String == "manual",
                    result["secondPeople"] as? String == "单人",
                    result["secondSetting"] as? String == "室内",
                    result["selectedSecond"] as? Bool == true,
                    result["saved"] as? String == "室内",
                    (result["saveState"] as? String)?.contains("自动保存") == true
                else {
                    fputs("TEST_ERROR invalid basic scene workflow \(value as? String ?? "nil")\n", stderr)
                    self.finished = true
                    NSApp.terminate(nil)
                    return
                }
                self.finished = true
                print("BASIC_SCENE_WORKFLOW_TEST_OK")
                NSApp.terminate(nil)
            }
        }
    }
}

@main
struct BasicSceneWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = BasicSceneWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
