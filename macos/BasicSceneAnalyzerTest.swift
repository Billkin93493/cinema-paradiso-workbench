import Foundation

@main
struct BasicSceneAnalyzerTestRunner {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let frames = [
            BasicSceneFrame(
                shotKey: "shot-outdoor",
                imageURL: root.appendingPathComponent("preview/assets/still-07.png")
            ),
            BasicSceneFrame(
                shotKey: "shot-indoor",
                imageURL: root.appendingPathComponent("preview/assets/still-08.png")
            ),
        ]
        let results = try BasicSceneAnalyzer.analyze(frames: frames) { _ in }

        guard
            let outdoor = results["shot-outdoor"],
            outdoor.people.value == "双人",
            outdoor.setting.value == "室外",
            outdoor.people.confidence >= 0.6,
            let indoor = results["shot-indoor"],
            ["单人", "双人", "多人"].contains(indoor.people.value),
            indoor.setting.value == "室内",
            results.count == 2
        else {
            throw NSError(domain: "BasicSceneAnalyzerTest", code: 1)
        }

        print(
            "BASIC_SCENE_ANALYZER_TEST_OK "
                + "outdoor=\(outdoor.people.value)/\(outdoor.timeOfDay.value)/\(outdoor.setting.value) "
                + "indoor=\(indoor.people.value)/\(indoor.timeOfDay.value)/\(indoor.setting.value)"
        )
    }
}
