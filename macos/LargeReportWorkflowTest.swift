import Cocoa
import WebKit

final class LargeReportWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private enum Phase {
        case cover
        case lastShotPage
    }

    private var webView: WKWebView!
    private var window: NSWindow!
    private var phase: Phase = .cover
    private var finished = false
    private var coverResult: [String: Any] = [:]

    private var rootURL: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1200, height: 900))
        webView.navigationDelegate = self
        window = NSWindow(
            contentRect: NSRect(x: -2400, y: -2400, width: 1200, height: 900),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.orderFront(nil)
        loadReportPage(previewKey: "cover")

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if !self.finished {
                fputs("TEST_ERROR large report timeout\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }

    private func loadReportPage(previewKey: String) {
        var components = URLComponents(
            url: rootURL.appendingPathComponent("report/index.html"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "embed", value: "1"),
            URLQueryItem(name: "preview", value: previewKey),
            URLQueryItem(name: "pages", value: "cover,overview,shots"),
            URLQueryItem(name: "fields", value: "images,sound,analysis"),
        ]
        webView.loadFileURL(
            components.url!,
            allowingReadAccessTo: URL(fileURLWithPath: "/")
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.renderAndVerify()
        }
    }

    private func makeReport() throws -> String {
        let shots: [[String: Any]] = (0..<1200).map { index in
            let start = Double(index) * 6
            return [
                "key": "shot-\(index)",
                "number": index + 1,
                "start": start,
                "end": start + 6,
                "size": index % 4 == 0 ? "全景" : "中景",
                "angle": index % 7 == 0 ? "俯视" : "平视",
                "movement": index % 5 == 0 ? "跟拍" : "固定",
                "action": "",
                "sound": "",
                "dialogueItems": [],
                "dialogueText": "",
                "note": index == 1199 ? "最后一镜压力测试导演笔记" : "",
                "imageUrl": "",
            ]
        }
        let report: [String: Any] = [
            "version": 1,
            "generatedAt": "2026-06-14T00:00:00Z",
            "generatedDate": "2026/06/14",
            "project": [
                "name": "两小时压力测试影片",
                "duration": 7200.0,
                "mode": "local",
            ],
            "shots": shots,
            "noteCount": 1,
            "frameCount": 0,
            "coverImageUrl": "",
        ]
        let data = try JSONSerialization.data(withJSONObject: report)
        return String(data: data, encoding: .utf8)!
    }

    private func renderAndVerify() {
        do {
            let reportJSON = try makeReport()
            let script = """
            const startedAt = performance.now();
            window.renderCinemaReport(\(reportJSON));
            JSON.stringify({
              title: document.title,
              pageCount: document.querySelectorAll(".report-page[data-page-key]").length,
              pageKey: document.querySelector(".report-page[data-page-key]")?.dataset.pageKey || "",
              shotRows: document.querySelectorAll(".shot-row:not(.shot-head)").length,
              lastNote: [...document.querySelectorAll(".shot-row:not(.shot-head) > :last-child")]
                .at(-1)?.textContent?.trim() || "",
              renderMs: Math.round(performance.now() - startedAt)
            });
            """
            webView.evaluateJavaScript(script) { value, error in
                if let error {
                    fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                    self.finish()
                    return
                }
                guard
                    let json = value as? String,
                    let data = json.data(using: .utf8),
                    let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    fputs("TEST_ERROR invalid large report result\n", stderr)
                    self.finish()
                    return
                }
                self.handle(result)
            }
        } catch {
            fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
            finish()
        }
    }

    private func handle(_ result: [String: Any]) {
        switch phase {
        case .cover:
            guard
                result["title"] as? String == "《两小时压力测试影片》逐镜拉片报告",
                result["pageCount"] as? Int == 1,
                result["pageKey"] as? String == "cover",
                result["shotRows"] as? Int == 0
            else {
                fputs("TEST_ERROR invalid cover \(result)\n", stderr)
                finish()
                return
            }
            coverResult = result
            phase = .lastShotPage
            loadReportPage(previewKey: "shots-300")

        case .lastShotPage:
            guard
                result["pageCount"] as? Int == 1,
                result["pageKey"] as? String == "shots-300",
                result["shotRows"] as? Int == 4,
                result["lastNote"] as? String == "最后一镜压力测试导演笔记"
            else {
                fputs("TEST_ERROR invalid last shot page \(result)\n", stderr)
                finish()
                return
            }
            let output: [String: Any] = [
                "shots": 1200,
                "reportPages": 302,
                "cover": coverResult,
                "lastShotPage": result,
            ]
            let data = try! JSONSerialization.data(
                withJSONObject: output,
                options: [.prettyPrinted, .sortedKeys]
            )
            print(String(data: data, encoding: .utf8)!)
            finish()
        }
    }

    private func finish() {
        finished = true
        NSApp.terminate(nil)
    }
}

@main
struct LargeReportWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = LargeReportWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
