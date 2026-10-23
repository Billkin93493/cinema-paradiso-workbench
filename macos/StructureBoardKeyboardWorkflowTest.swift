import Cocoa
import WebKit

final class StructureBoardKeyboardWorkflowTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
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
                window.cinemaDesktop = {
                  getRecentProject: async () => null,
                  getArchiveFrames: async () => [],
                  getArchiveClips: async () => [],
                  saveAnalysis: async (analysis) => {
                    window.__testSavedAnalysis = JSON.parse(JSON.stringify(analysis));
                    return {
                      name: "结构画板测试影片",
                      filePath: "/tmp/structure-board-test.mov",
                      fileUrl: "",
                      duration: 16,
                      updatedAt: new Date().toISOString(),
                      analysis: window.__testSavedAnalysis
                    };
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
              currentLocalProject = {
                name: "结构画板测试影片",
                filePath: "/tmp/structure-board-test.mov",
                fileUrl: "",
                duration: 16,
                updatedAt: new Date().toISOString()
              };
              manualAnalysis = {
                mode: "manual",
                cutPoints: [0, 16],
                shotData: {},
                structureBoard: {
                  version: 1,
                  updatedAt: new Date().toISOString(),
                  nodes: [
                    { id: "root", title: "影片结构", x: 72, y: 310, parentId: null, type: "root" },
                    { id: "topic", title: "人物关系", x: 300, y: 250, parentId: "root", type: "topic" },
                    { id: "branch", title: "隐藏动机", x: 540, y: 250, parentId: "topic", type: "topic" }
                  ]
                }
              };
              openStructureBoard();
              addStructureNode("root");
              await new Promise((resolve) => setTimeout(resolve, 120));
              const topicInput = document.querySelector(".structure-board-node-input");
              topicInput.value = "三幕结构";
              topicInput.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
              await new Promise((resolve) => setTimeout(resolve, 750));
              const addedTopic = manualAnalysis.structureBoard.nodes.find((node) => node.title === "三幕结构");
              const savedTopicTitle = window.__testSavedAnalysis?.structureBoard?.nodes?.find((node) => node.id === addedTopic?.id)?.title || "";

              addStructureNode(addedTopic.id);
              await new Promise((resolve) => setTimeout(resolve, 120));
              const branchInput = document.querySelector(".structure-board-node-input");
              branchInput.value = "反转分支";
              branchInput.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
              await new Promise((resolve) => setTimeout(resolve, 750));
              const addedBranch = manualAnalysis.structureBoard.nodes.find((node) => node.title === "反转分支");
              const savedBranchTitle = window.__testSavedAnalysis?.structureBoard?.nodes?.find((node) => node.id === addedBranch?.id)?.title || "";

              activeStructureNodeId = "topic";
              renderStructureBoardEditor();
              document.dispatchEvent(new KeyboardEvent("keydown", { key: "Delete", bubbles: true }));
              await new Promise((resolve) => setTimeout(resolve, 750));
              const afterTopicDelete = manualAnalysis.structureBoard.nodes.map((node) => node.id);
              const savedAfterDelete = window.__testSavedAnalysis?.structureBoard?.nodes?.map((node) => node.id) || [];

              activeStructureNodeId = "root";
              renderStructureBoardEditor();
              document.dispatchEvent(new KeyboardEvent("keydown", { key: "Backspace", bubbles: true }));
              await new Promise((resolve) => setTimeout(resolve, 100));
              const afterRootDelete = manualAnalysis.structureBoard.nodes.map((node) => node.id);

              window.__structureBoardKeyboardResult = {
                addedTopicTitle: addedTopic?.title || "",
                addedBranchTitle: addedBranch?.title || "",
                savedTopicTitle,
                savedBranchTitle,
                afterTopicDelete,
                savedAfterDelete,
                afterRootDelete,
                selectedNode: activeStructureNodeId,
                overlayOpen: !structureBoardOverlay.hidden
              };
            })();
            """
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            webView.evaluateJavaScript(
                "JSON.stringify(window.__structureBoardKeyboardResult)"
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
                fputs("TEST_ERROR invalid structure board delete result: \(String(describing: value))\n", stderr)
                self.finished = true
                NSApp.terminate(nil)
                return
            }

            self.finished = true
            print("STRUCTURE_BOARD_KEYBOARD_TEST_OK")
            NSApp.terminate(nil)
            }
        }
    }

    private func isValid(_ result: [String: Any]) -> Bool {
        guard
            result["addedTopicTitle"] as? String == "三幕结构",
            result["addedBranchTitle"] as? String == "反转分支",
            result["savedTopicTitle"] as? String == "三幕结构",
            result["savedBranchTitle"] as? String == "反转分支",
            let afterTopicDelete = result["afterTopicDelete"] as? [String],
            afterTopicDelete.contains("root"),
            afterTopicDelete.contains(where: { $0 != "root" }),
            let savedAfterDelete = result["savedAfterDelete"] as? [String],
            savedAfterDelete.contains("root"),
            savedAfterDelete.contains(where: { $0 != "root" }),
            let afterRootDelete = result["afterRootDelete"] as? [String],
            afterRootDelete == savedAfterDelete,
            result["selectedNode"] as? String == "root",
            result["overlayOpen"] as? Bool == true
        else {
            return false
        }
        return true
    }
}

@main
struct StructureBoardKeyboardWorkflowTestRunner {
    static func main() {
        let application = NSApplication.shared
        let delegate = StructureBoardKeyboardWorkflowTest()
        application.delegate = delegate
        application.run()
    }
}
