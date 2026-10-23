import Cocoa
import WebKit

final class PlayerWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
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
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [],
                  getArchiveClips: async () => [],
                  updateProject: async (updates) => ({
                    name: "播放器测试影片",
                    filePath: "",
                    fileUrl: window.__testVideoUrl,
                    duration: updates.duration || 0
                  }),
                  saveAnalysis: async (analysis) => ({
                    name: "播放器测试影片",
                    filePath: "",
                    fileUrl: window.__testVideoUrl,
                    duration: document.querySelector("#local-video")?.duration || 0,
                    analysis
                  })
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
            applyLocalProject({
              name: "播放器测试影片",
              filePath: "",
              fileUrl: window.__testVideoUrl,
              duration: 0
            }, true);
            """
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            webView.evaluateJavaScript(
                """
                localVideo.pause();
                localVideo.currentTime = 8;
                playerSkipBack.click();
                window.__afterBack = localVideo.currentTime;
                playerFrameForward.click();
                window.__afterFrame = localVideo.currentTime;
                playerSkipForward.click();
                window.__afterForward = localVideo.currentTime;
                playerSpeedButton.click();
                window.__afterSpeed = localVideo.playbackRate;
                document.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowLeft", bubbles: true }));
                window.__afterShortcut = localVideo.currentTime;

                const scrubberBounds = playerScrubber.getBoundingClientRect();
                activeClipPlaybackEnd = localVideo.duration * 0.8;
                activeClipPlaybackContinue = true;
                playerScrubber.dispatchEvent(new PointerEvent("pointerdown", {
                  bubbles: true,
                  clientX: scrubberBounds.left + scrubberBounds.width * 0.25,
                  pointerId: 1,
                  buttons: 1
                }));
                playerScrubber.dispatchEvent(new PointerEvent("pointerup", {
                  bubbles: true,
                  clientX: scrubberBounds.left + scrubberBounds.width * 0.25,
                  pointerId: 1
                }));
                window.__afterScrubberClick = localVideo.currentTime;
                window.__clipBoundaryCleared = activeClipPlaybackEnd === null
                  && activeClipPlaybackContinue === false;

                playerScrubber.dispatchEvent(new PointerEvent("pointerdown", {
                  bubbles: true,
                  clientX: scrubberBounds.left + scrubberBounds.width * 0.2,
                  pointerId: 2,
                  buttons: 1
                }));
                playerScrubber.dispatchEvent(new PointerEvent("pointermove", {
                  bubbles: true,
                  clientX: scrubberBounds.left + scrubberBounds.width * 0.7,
                  pointerId: 2,
                  buttons: 1
                }));
                playerScrubber.dispatchEvent(new PointerEvent("pointerup", {
                  bubbles: true,
                  clientX: scrubberBounds.left + scrubberBounds.width * 0.7,
                  pointerId: 2
                }));
                window.__afterScrubberDrag = localVideo.currentTime;
                window.__testDuration = localVideo.duration;
                """
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            webView.evaluateJavaScript(
                """
                JSON.stringify({
                  afterBack: window.__afterBack,
                  afterFrame: window.__afterFrame,
                  afterForward: window.__afterForward,
                  afterSpeed: window.__afterSpeed,
                  afterShortcut: window.__afterShortcut,
                  afterScrubberClick: window.__afterScrubberClick,
                  afterScrubberDrag: window.__afterScrubberDrag,
                  clipBoundaryCleared: window.__clipBoundaryCleared,
                  duration: window.__testDuration,
                  speedLabel: playerSpeedButton.textContent,
                  controlCount: document.querySelectorAll(".transport-controls button").length,
                  workbenchActive: document.querySelector("#workbench-page").classList.contains("active")
                })
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
                    let duration = result["duration"] as? Double,
                    let clickTime = result["afterScrubberClick"] as? Double,
                    let dragTime = result["afterScrubberDrag"] as? Double,
                    duration > 0,
                    abs(clickTime / duration - 0.25) < 0.03,
                    abs(dragTime / duration - 0.7) < 0.03,
                    result["clipBoundaryCleared"] as? Bool == true
                else {
                    fputs("TEST_ERROR invalid player workflow \(value as? String ?? "nil")\n", stderr)
                    self.finished = true
                    NSApp.terminate(nil)
                    return
                }
                self.finished = true
                print("PLAYER_WORKFLOW_TEST_OK")
                NSApp.terminate(nil)
            }
        }
    }
}

@main
struct PlayerWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = PlayerWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
