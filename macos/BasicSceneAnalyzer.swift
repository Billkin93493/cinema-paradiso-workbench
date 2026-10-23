import AppKit
import Vision

struct BasicSceneFrame {
    let shotKey: String
    let imageURL: URL
}

struct BasicSceneFieldResult {
    let value: String
    let confidence: Double

    var bridgeValue: [String: Any] {
        [
            "value": value,
            "confidence": confidence,
            "source": "auto",
        ]
    }
}

struct BasicSceneResult {
    let shotKey: String
    let people: BasicSceneFieldResult
    let timeOfDay: BasicSceneFieldResult
    let setting: BasicSceneFieldResult

    var bridgeValue: [String: Any] {
        [
            "shotKey": shotKey,
            "people": people.bridgeValue,
            "timeOfDay": timeOfDay.bridgeValue,
            "setting": setting.bridgeValue,
        ]
    }
}

enum BasicSceneAnalyzerError: LocalizedError {
    case noFrames

    var errorDescription: String? {
        "没有取得可以识别的代表静帧"
    }
}

enum BasicSceneAnalyzer {
    private struct ImageStats {
        let mean: Double
        let darkRatio: Double
        let brightRatio: Double
    }

    static func analyze(
        frames: [BasicSceneFrame],
        progress: @escaping (_ percent: Int) -> Void
    ) throws -> [String: BasicSceneResult] {
        guard !frames.isEmpty else {
            throw BasicSceneAnalyzerError.noFrames
        }

        var results: [String: BasicSceneResult] = [:]
        for (index, frame) in frames.enumerated() {
            autoreleasepool {
                if let result = analyze(frame: frame) {
                    results[frame.shotKey] = result
                }
            }
            progress(Int((Double(index + 1) / Double(frames.count)) * 100))
        }

        guard !results.isEmpty else {
            throw BasicSceneAnalyzerError.noFrames
        }
        return results
    }

    private static func analyze(frame: BasicSceneFrame) -> BasicSceneResult? {
        guard
            frame.imageURL.isFileURL,
            let image = NSImage(contentsOf: frame.imageURL),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let classificationRequest = VNClassifyImageRequest()
        let fullBodyRequest = VNDetectHumanRectanglesRequest()
        fullBodyRequest.upperBodyOnly = false
        let upperBodyRequest = VNDetectHumanRectanglesRequest()
        upperBodyRequest.upperBodyOnly = true

        do {
            try VNImageRequestHandler(cgImage: cgImage).perform([
                classificationRequest,
                fullBodyRequest,
                upperBodyRequest,
            ])
        } catch {
            return nil
        }

        let labels = Dictionary(
            (classificationRequest.results ?? []).map {
                ($0.identifier.lowercased(), Double($0.confidence))
            },
            uniquingKeysWith: max
        )
        let people = peopleResult(
            fullBody: fullBodyRequest.results ?? [],
            upperBody: upperBodyRequest.results ?? [],
            labels: labels
        )
        let stats = imageStats(cgImage)
        return BasicSceneResult(
            shotKey: frame.shotKey,
            people: people,
            timeOfDay: timeOfDayResult(labels: labels, stats: stats),
            setting: settingResult(labels: labels)
        )
    }

    private static func peopleResult(
        fullBody: [VNHumanObservation],
        upperBody: [VNHumanObservation],
        labels: [String: Double]
    ) -> BasicSceneFieldResult {
        let chosen = fullBody.count >= upperBody.count ? fullBody : upperBody
        var count = chosen.count
        var confidence: Double

        if count > 0 {
            confidence = chosen.map { Double($0.confidence) }.reduce(0, +) / Double(count)
        } else {
            let peopleLabel = labels["people"] ?? 0
            if peopleLabel >= 0.28 {
                count = 1
                confidence = min(0.62, max(0.48, peopleLabel * 0.72))
            } else {
                confidence = min(0.9, max(0.56, 0.88 - peopleLabel * 0.65))
            }
        }

        let value: String
        switch count {
        case 0:
            value = "无人"
        case 1:
            value = "单人"
        case 2:
            value = "双人"
        default:
            value = "多人"
        }
        return BasicSceneFieldResult(value: value, confidence: clamp(confidence))
    }

    private static func timeOfDayResult(
        labels: [String: Double],
        stats: ImageStats
    ) -> BasicSceneFieldResult {
        let nightLabel = maximum(labels, keys: [
            "night_sky", "nighttime", "nightclub",
        ])
        let dayLabel = maximum(labels, keys: [
            "daytime", "blue_sky", "sun", "sunlight",
        ])
        let sunset = labels["sunset_sunrise"] ?? 0
        let darkness = max(0, min(1, (0.34 - stats.mean) / 0.27))
        let daylight = max(0, min(1, (stats.mean - 0.2) / 0.48))
        let nightScore = max(nightLabel, darkness * 0.86, stats.darkRatio * 0.7)
        let dayScore = max(dayLabel, daylight * 0.82, stats.brightRatio * 0.64)

        if sunset >= 0.18 || abs(nightScore - dayScore) < 0.13 {
            return BasicSceneFieldResult(
                value: "不确定",
                confidence: clamp(max(nightScore, dayScore), minimum: 0.45, maximum: 0.64)
            )
        }
        if nightScore > dayScore {
            return BasicSceneFieldResult(
                value: "夜景",
                confidence: clamp(nightScore, minimum: 0.55, maximum: 0.94)
            )
        }
        return BasicSceneFieldResult(
            value: "日景",
            confidence: clamp(dayScore, minimum: 0.55, maximum: 0.94)
        )
    }

    private static func settingResult(labels: [String: Double]) -> BasicSceneFieldResult {
        let outdoor = max(
            maximum(labels, keys: ["outdoor"]),
            weightedMaximum(labels, values: [
                "sky": 0.9,
                "blue_sky": 0.95,
                "land": 0.78,
                "road": 0.82,
                "street": 0.82,
                "path": 0.7,
                "hill": 0.74,
                "mountain": 0.82,
                "ocean": 0.86,
                "beach": 0.86,
                "forest": 0.82,
                "field": 0.8,
                "cityscape": 0.82,
            ])
        )
        let indoor = max(
            maximum(labels, keys: [
                "interior_room", "bedroom", "bathroom_room", "classroom",
                "dining_room", "kitchen_room", "living_room",
            ]),
            weightedMaximum(labels, values: [
                "furniture": 0.72,
                "table": 0.64,
                "bed": 0.8,
                "couch": 0.78,
                "ceiling": 0.86,
                "appliance": 0.72,
                "tableware": 0.55,
            ])
        )

        if outdoor >= 0.2 && outdoor > indoor + 0.07 {
            return BasicSceneFieldResult(
                value: "室外",
                confidence: clamp(outdoor, minimum: 0.58, maximum: 0.95)
            )
        }
        if indoor >= 0.1 && indoor > outdoor + 0.045 {
            return BasicSceneFieldResult(
                value: "室内",
                confidence: clamp(indoor * 1.4, minimum: 0.56, maximum: 0.92)
            )
        }
        return BasicSceneFieldResult(
            value: "不确定",
            confidence: clamp(max(indoor, outdoor), minimum: 0.44, maximum: 0.62)
        )
    }

    private static func imageStats(_ image: CGImage) -> ImageStats {
        let width = 96
        let height = 54
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return ImageStats(mean: 0.5, darkRatio: 0, brightRatio: 0)
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total = 0.0
        var dark = 0
        var bright = 0
        let count = width * height
        for index in 0..<count {
            let offset = index * 4
            let luminance = (
                0.2126 * Double(pixels[offset])
                + 0.7152 * Double(pixels[offset + 1])
                + 0.0722 * Double(pixels[offset + 2])
            ) / 255
            total += luminance
            if luminance < 0.18 { dark += 1 }
            if luminance > 0.72 { bright += 1 }
        }
        return ImageStats(
            mean: total / Double(count),
            darkRatio: Double(dark) / Double(count),
            brightRatio: Double(bright) / Double(count)
        )
    }

    private static func maximum(_ labels: [String: Double], keys: [String]) -> Double {
        keys.map { labels[$0] ?? 0 }.max() ?? 0
    }

    private static func weightedMaximum(
        _ labels: [String: Double],
        values: [String: Double]
    ) -> Double {
        values.map { (labels[$0.key] ?? 0) * $0.value }.max() ?? 0
    }

    private static func clamp(
        _ value: Double,
        minimum: Double = 0.42,
        maximum: Double = 0.96
    ) -> Double {
        min(maximum, max(minimum, value))
    }
}
