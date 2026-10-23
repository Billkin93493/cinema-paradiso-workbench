import Cocoa
import WebKit

final class AITranslationWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                window.__aiConfigured = false;
                window.__savedKeyLength = 0;
                window.__translateCalls = 0;
                window.__translationShouldFail = false;
                window.__savedAnalysis = null;
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [],
                  getArchiveClips: async () => [],
                  getAITranslationSettings: async () => ({ configured: window.__aiConfigured }),
                  saveAITranslationKey: async ({ key }) => {
                    window.__savedKeyLength = key.length;
                    window.__aiConfigured = true;
                    return { configured: true };
                  },
                  removeAITranslationKey: async () => {
                    window.__aiConfigured = false;
                    return { configured: false };
                  },
                  translateSubtitles: async ({ cues }, onProgress) => {
                    window.__translateCalls += 1;
                    if (window.__translationShouldFail) {
                      return {
                        model: "deepseek-v4-flash",
                        translations: [],
                        translatedCount: 0,
                        requestedCount: cues.length,
                        error: "DeepSeek 服务暂时繁忙，请稍后重试"
                      };
                    }
                    onProgress?.({ translated: 1, total: cues.length, percent: 50 });
                    onProgress?.({ translated: cues.length, total: cues.length, percent: 100 });
                    return {
                      model: "deepseek-v4-flash",
                      translations: cues.map((cue) => ({
                        id: cue.id,
                        text: cue.id === 0 ? "你好。" : "我们走吧。"
                      })),
                      translatedCount: cues.length,
                      requestedCount: cues.length
                    };
                  },
                  saveAnalysis: async (analysis) => {
                    window.__savedAnalysis = JSON.parse(JSON.stringify(analysis));
                    return {
                      name: "英文字幕测试影片",
                      filePath: "",
                      fileUrl: "",
                      duration: 8,
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
        webView.evaluateJavaScript(
            """
            openPage("workbench");
            currentLocalProject = {
              name: "英文字幕测试影片",
              filePath: "",
              fileUrl: "",
              duration: 8
            };
            manualAnalysis = {
              mode: "manual",
              cutPoints: [0, 4, 8],
              cutConfidence: {},
              shotData: {},
              representativeFrames: {},
              subtitles: {
                found: true,
                sourceName: "英文字幕测试影片.en.srt",
                language: "en",
                isChinese: false,
                cues: [
                  { start: 1, end: 3, text: "Hello." },
                  { start: 4, end: 6, text: "Let's go." }
                ]
              }
            };
            initializeManualAnalysis(8);
            openAITranslationButton.click();
            """
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.evaluateJavaScript(
                """
                window.__dialogOpened = !aiTranslationOverlay.hidden;
                window.__initialStartDisabled = startAITranslationButton.disabled;
                window.__callsBeforeClick = window.__translateCalls;
                aiTranslationKeyInput.value = "sk-test-key-for-workflow-check";
                saveAITranslationButton.click();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            webView.evaluateJavaScript(
                """
                window.__savedState = {
                  dialogOpenAfterSave: !aiTranslationOverlay.hidden,
                  status: aiTranslationStatus.textContent,
                  configuredClass: openAITranslationButton.classList.contains("configured"),
                  savedKeyLength: window.__savedKeyLength,
                  startEnabled: !startAITranslationButton.disabled
                };
                startAITranslationButton.click();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            webView.evaluateJavaScript(
                """
                window.__translationSuccess = {
                  translateCalls: window.__translateCalls,
                  translatedCount: window.__savedAnalysis?.subtitleTranslation?.translatedCount,
                  status: window.__savedAnalysis?.subtitleTranslation?.status,
                  originalText: window.__savedAnalysis?.subtitleTranslation?.translations?.[0]?.originalText,
                  translatedText: window.__savedAnalysis?.subtitleTranslation?.translations?.[0]?.translatedText,
                  assignedTranslation: window.__savedAnalysis?.subtitleAssignments?.byShot?.["shot-0"]?.translatedText,
                  containsKey: JSON.stringify(window.__savedAnalysis || {}).includes("sk-test-key-for-workflow-check")
                };
                window.__translationShouldFail = true;
                startAITranslationButton.click();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            webView.evaluateJavaScript(
                """
                window.__failureState = {
                  error: aiTranslationError.textContent,
                  translatedTextStillSaved: window.__savedAnalysis?.subtitleTranslation?.translations?.[0]?.translatedText
                };
                window.__removeVisible = !removeAITranslationKeyButton.hidden;
                removeAITranslationKeyButton.click();
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.9) {
            webView.evaluateJavaScript(
                """
                JSON.stringify({
                  dialogOpened: window.__dialogOpened,
                  initialStartDisabled: window.__initialStartDisabled,
                  callsBeforeClick: window.__callsBeforeClick,
                  savedState: window.__savedState,
                  translationSuccess: window.__translationSuccess,
                  failureState: window.__failureState,
                  removeVisible: window.__removeVisible,
                  removedStatus: aiTranslationStatus.textContent,
                  removedConfiguredClass: openAITranslationButton.classList.contains("configured"),
                  dialogClosedAfterRemove: aiTranslationOverlay.hidden
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
struct AITranslationWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = AITranslationWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
