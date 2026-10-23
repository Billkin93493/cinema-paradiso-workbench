import Cocoa
import WebKit

final class SubtitleDialogueWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
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
                      name: "字幕编辑测试影片",
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
              name: "字幕编辑测试影片",
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
                sourceName: "字幕编辑测试影片.en.srt",
                language: "en",
                isChinese: false,
                cues: [
                  { start: 3, end: 5, text: "I did not know." },
                  { start: 5, end: 6.5, text: "Neither did I." }
                ]
              },
              subtitleTranslation: {
                provider: "deepseek",
                model: "deepseek-v4-flash",
                sourceName: "字幕编辑测试影片.en.srt",
                cueCount: 2,
                translatedCount: 2,
                status: "complete",
                translations: [
                  { cueIndex: 0, originalText: "I did not know.", translatedText: "我不知道。" },
                  { cueIndex: 1, originalText: "Neither did I.", translatedText: "我也不知道。" }
                ]
              }
            };
            initializeManualAnalysis(8);
            selectedManualShotKey = "shot-0";
            updateShotEditor(manualShots()[0]);
            renderManualShots();
            subtitleDialogueTab.click();
            window.__initialState = {
              analysisHidden: directorAnalysisPanel.hidden,
              subtitlesVisible: !subtitleDialoguePanel.hidden,
              cueCount: subtitleDialogueList.querySelectorAll(".subtitle-cue-card").length,
              fieldCount: subtitleDialogueList.querySelectorAll("textarea").length,
              tabCount: subtitleTabCount.textContent
            };

            const firstCard = subtitleDialogueList.querySelector('[data-cue-index="0"]');
            const original = firstCard.querySelector('[data-subtitle-field="originalText"]');
            const translated = firstCard.querySelector('[data-subtitle-field="translatedText"]');
            original.value = "I truly did not know.";
            original.dispatchEvent(new Event("input", { bubbles: true }));
            translated.value = "我真的不知道。";
            translated.dispatchEvent(new Event("input", { bubbles: true }));
            """
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            webView.evaluateJavaScript(
                """
                window.__afterSave = {
                  savedOriginalEdit: window.__savedAnalysis?.subtitleEdits?.byCue?.["0"]?.originalText,
                  savedTranslatedEdit: window.__savedAnalysis?.subtitleEdits?.byCue?.["0"]?.translatedText,
                  rawSubtitleUnchanged: window.__savedAnalysis?.subtitles?.cues?.[0]?.text,
                  firstShotOriginal: window.__savedAnalysis?.subtitleAssignments?.byShot?.["shot-0"]?.cues?.[0]?.text,
                  firstShotTranslation: window.__savedAnalysis?.subtitleAssignments?.byShot?.["shot-0"]?.cues?.[0]?.translatedText,
                  secondShotOriginal: window.__savedAnalysis?.subtitleAssignments?.byShot?.["shot-4000"]?.cues?.[0]?.text,
                  saveState: subtitleSaveState.textContent
                };

                selectManualShot("shot-4000", false);
                const spanningCard = subtitleDialogueList.querySelector('[data-cue-index="0"]');
                window.__secondShot = {
                  cueCount: subtitleDialogueList.querySelectorAll(".subtitle-cue-card").length,
                  original: spanningCard.querySelector('[data-subtitle-field="originalText"]').value,
                  translated: spanningCard.querySelector('[data-subtitle-field="translatedText"]').value,
                  tabCount: subtitleTabCount.textContent
                };

                manualAnalysis = JSON.parse(JSON.stringify(window.__savedAnalysis));
                initializeManualAnalysis(8);
                selectedManualShotKey = "shot-0";
                updateShotEditor(manualShots()[0]);
                setWorkbenchSideTab("subtitles");
                const reopenedCard = subtitleDialogueList.querySelector('[data-cue-index="0"]');
                const reopenedState = {
                  original: reopenedCard.querySelector('[data-subtitle-field="originalText"]').value,
                  translated: reopenedCard.querySelector('[data-subtitle-field="translatedText"]').value
                };

                manualAnalysis = {
                  mode: "manual",
                  cutPoints: [0, 4],
                  cutConfidence: {},
                  shotData: {},
                  representativeFrames: {},
                  subtitles: {
                    found: true,
                    sourceName: "中文字幕.srt",
                    language: "zh-CN",
                    isChinese: true,
                    cues: [{ start: 1, end: 2, text: "只显示一个字幕对白框" }]
                  }
                };
                initializeManualAnalysis(4);
                selectedManualShotKey = "shot-0";
                renderSubtitleDialoguePanel();
                const chineseState = {
                  fieldCount: subtitleDialogueList.querySelectorAll("textarea").length,
                  language: subtitleLanguageState.textContent
                };

                manualAnalysis.subtitles = {
                  found: false,
                  sourceName: "",
                  language: "",
                  isChinese: false,
                  cues: []
                };
                initializeManualAnalysis(4);
                renderSubtitleDialoguePanel();
                JSON.stringify({
                  initial: window.__initialState,
                  afterSave: window.__afterSave,
                  secondShot: window.__secondShot,
                  reopened: reopenedState,
                  chinese: chineseState,
                  empty: {
                    visible: !subtitleDialogueEmpty.hidden,
                    title: subtitleDialogueEmpty.querySelector("strong").textContent
                  }
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
                    self.isValid(result)
                else {
                    fputs("TEST_ERROR invalid subtitle dialogue workflow\n", stderr)
                    self.finished = true
                    NSApp.terminate(nil)
                    return
                }

                self.finished = true
                print("SUBTITLE_DIALOGUE_TEST_OK")
                NSApp.terminate(nil)
            }
        }
    }

    private func isValid(_ result: [String: Any]) -> Bool {
        guard
            let initial = result["initial"] as? [String: Any],
            initial["analysisHidden"] as? Bool == true,
            initial["subtitlesVisible"] as? Bool == true,
            initial["cueCount"] as? Int == 1,
            initial["fieldCount"] as? Int == 2,
            initial["tabCount"] as? String == "1",
            let afterSave = result["afterSave"] as? [String: Any],
            afterSave["savedOriginalEdit"] as? String == "I truly did not know.",
            afterSave["savedTranslatedEdit"] as? String == "我真的不知道。",
            afterSave["rawSubtitleUnchanged"] as? String == "I did not know.",
            afterSave["firstShotOriginal"] as? String == "I truly did not know.",
            afterSave["firstShotTranslation"] as? String == "我真的不知道。",
            afterSave["secondShotOriginal"] as? String == "I truly did not know.",
            (afterSave["saveState"] as? String)?.contains("已自动保存") == true,
            let secondShot = result["secondShot"] as? [String: Any],
            secondShot["cueCount"] as? Int == 2,
            secondShot["original"] as? String == "I truly did not know.",
            secondShot["translated"] as? String == "我真的不知道。",
            secondShot["tabCount"] as? String == "2",
            let reopened = result["reopened"] as? [String: Any],
            reopened["original"] as? String == "I truly did not know.",
            reopened["translated"] as? String == "我真的不知道。",
            let chinese = result["chinese"] as? [String: Any],
            chinese["fieldCount"] as? Int == 1,
            (chinese["language"] as? String)?.contains("中文字幕") == true,
            let empty = result["empty"] as? [String: Any],
            empty["visible"] as? Bool == true,
            empty["title"] as? String == "当前影片没有可读取字幕"
        else {
            return false
        }
        return true
    }
}

@main
struct SubtitleDialogueWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = SubtitleDialogueWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
