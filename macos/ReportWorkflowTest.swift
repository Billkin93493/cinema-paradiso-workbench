import Cocoa
import WebKit

final class ReportWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var finished = false

    private var rootURL: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private var outputDirectoryURL: URL {
        rootURL.appendingPathComponent("tmp/pdfs", isDirectory: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(
            at: outputDirectoryURL,
            withIntermediateDirectories: true
        )

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

        let report = makeReport()
        let data = try! JSONSerialization.data(withJSONObject: report)
        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let reportURL = rootURL
            .appendingPathComponent("report/index.html")
            .absoluteString
            + "?pages=cover,overview,shots&fields=images,sound,analysis#data=\(encoded)"
        webView.loadFileURL(
            URL(string: reportURL)!,
            allowingReadAccessTo: URL(fileURLWithPath: "/")
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if !self.finished {
                fputs("TEST_ERROR report timeout\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }

    private func makeReport() -> [String: Any] {
        let imageOne = rootURL.appendingPathComponent("preview/assets/still-01.png").absoluteString
        let imageTwo = rootURL.appendingPathComponent("preview/assets/still-07.png").absoluteString
        let notes = [
            "人物停在门口后没有立刻进入，镜头保留空间距离，让迟疑先于对白出现。",
            "",
            "固定机位让两人的停顿成为主要动作，背景亮度变化承担时间流逝。",
            "前景遮挡将视线切成两部分，人物虽然处在同一空间，关系仍然没有真正靠近。",
            "",
            "最后一个镜头在动作完成后继续停留，让空画面接住前面没有说完的情绪。",
        ]
        let sizes = ["全景", "中景", "中景", "近景", "特写", "全景"]
        let movements = ["固定", "推镜", "固定", "横移", "固定", "固定"]
        let shots: [[String: Any]] = (0..<6).map { index in
            let start = Double(index) * 6.5
            return [
                "key": "shot-\(index)",
                "number": index + 1,
                "start": start,
                "end": start + 6.5,
                "size": sizes[index],
                "angle": index == 3 ? "俯视" : "平视",
                "movement": movements[index],
                "action": "",
                "sound": "",
                "dialogueItems": index == 0
                    ? [
                        [
                            "primary": "我不知道你会不会来。",
                            "secondary": "I didn't know if you'd come.",
                        ],
                        [
                            "primary": "但我还是等了。",
                            "secondary": "But I waited anyway.",
                        ],
                    ]
                    : (index == 1
                        ? [["primary": "我也不知道。", "secondary": "Neither did I."]]
                        : (index == 2 ? [["primary": "这是中文字幕。", "secondary": ""]] : [])),
                "dialogueText": index == 0
                    ? "我不知道你会不会来。\n原文：I didn't know if you'd come.\n\n但我还是等了。\n原文：But I waited anyway."
                    : (index == 1 ? "我也不知道。\n原文：Neither did I." : (index == 2 ? "这是中文字幕。" : "")),
                "note": notes[index],
                "imageUrl": index == 0 ? imageOne : (index == 3 ? imageTwo : ""),
            ]
        }
        return [
            "version": 1,
            "generatedAt": "2026-06-09T00:00:00Z",
            "generatedDate": "2026/06/09",
            "project": [
                "name": "自动测试影片",
                "duration": 39.0,
                "mode": "local",
            ],
            "shots": shots,
            "noteCount": 4,
            "frameCount": 2,
            "coverImageUrl": imageOne,
        ]
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.verifyAndExport()
        }
    }

    private func verifyAndExport() {
        webView.evaluateJavaScript(
            """
            JSON.stringify({
              title: document.title,
              pages: document.querySelectorAll(".report-page[data-page-key]").length,
              rows: document.querySelectorAll(".shot-row:not(.shot-head)").length,
              missingFrames: document.querySelectorAll(".shot-image .report-image-empty").length,
              dialogueCells: document.querySelectorAll(".sound-dialogue").length,
              bilingualItems: document.querySelectorAll(".dialogue-item small").length,
              firstDialogue: document.querySelector(".dialogue-item p")?.textContent,
              firstOriginal: document.querySelector(".dialogue-item small")?.textContent,
              combinedHeader: [...document.querySelectorAll(".shot-head span")]
                .some((element) => element.textContent === "声音 / 字幕对白"),
              notes: [...document.querySelectorAll(".shot-row:not(.shot-head) > :last-child")]
                .filter((element) => !element.classList.contains("empty-report-field")).length
            })
            """
        ) { value, error in
            if let error {
                fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                self.finish()
                return
            }

            self.webView.evaluateJavaScript(
                """
                document.body.classList.add("embed-mode");
                document.querySelectorAll(".report-page").forEach((page, index) => {
                  page.style.display = index === 0 ? "block" : "none";
                });
                """
            ) { _, _ in
                let pdfURL = self.outputDirectoryURL.appendingPathComponent("真实拉片报告-自动测试.pdf")
                let pdfConfiguration = WKPDFConfiguration()
                pdfConfiguration.rect = NSRect(x: 0, y: 0, width: 1120, height: 792)
                self.webView.createPDF(configuration: pdfConfiguration) { result in
                    let pdfCreated: Bool
                    switch result {
                    case .success(let data):
                        do {
                            try data.write(to: pdfURL, options: .atomic)
                            pdfCreated = true
                        } catch {
                            fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                            pdfCreated = false
                        }
                    case .failure(let error):
                        fputs("TEST_ERROR \(error.localizedDescription)\n", stderr)
                        pdfCreated = false
                    }

                    let configuration = WKSnapshotConfiguration()
                    configuration.rect = NSRect(x: 0, y: 0, width: 1120, height: 792)
                    self.webView.takeSnapshot(with: configuration) { image, snapshotError in
                        if let image,
                           let data = image.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: data),
                           let png = bitmap.representation(using: .png, properties: [:])
                        {
                            try? png.write(
                                to: self.outputDirectoryURL.appendingPathComponent("真实拉片报告-封面检查.png"),
                                options: .atomic
                            )
                        }
                        if let snapshotError {
                            fputs("TEST_ERROR \(snapshotError.localizedDescription)\n", stderr)
                        }
                        print(
                            "\(value as? String ?? "{}") PDF=\(pdfCreated) FILE=\(FileManager.default.fileExists(atPath: pdfURL.path))"
                        )
                        self.finish()
                    }
                }
            }
        }
    }

    private func finish() {
        finished = true
        NSApp.terminate(nil)
    }
}

@main
struct ReportWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = ReportWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
