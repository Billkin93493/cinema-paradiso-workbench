import AppKit
import Vision

struct HardSubtitleFrame {
    let shotKey: String
    let start: Double
    let end: Double
    let imageURL: URL
}

struct HardSubtitleCue {
    let start: Double
    let end: Double
    let text: String
    let confidence: Double
    let shotKeys: [String]

    var bridgeValue: [String: Any] {
        [
            "start": start,
            "end": end,
            "text": text,
            "confidence": confidence,
            "shotKeys": shotKeys,
        ]
    }
}

struct HardSubtitleReadResult {
    let cues: [HardSubtitleCue]
    let scannedShotCount: Int

    var bridgeValue: [String: Any] {
        let joinedText = cues.map(\.text).joined(separator: "\n")
        let isChinese = HardSubtitleRecognizer.containsChinese(joinedText)
        return [
            "found": !cues.isEmpty,
            "sourceType": "hard-ocr",
            "sourceName": "画面字幕识别",
            "language": isChinese ? "zh" : "",
            "isChinese": isChinese,
            "candidateCount": cues.isEmpty ? 0 : 1,
            "cueCount": cues.count,
            "scannedShotCount": scannedShotCount,
            "cues": cues.map(\.bridgeValue),
            "scannedAt": ISO8601DateFormatter().string(from: Date()),
        ]
    }
}

enum HardSubtitleRecognizerError: LocalizedError {
    case noFrames

    var errorDescription: String? {
        "没有可以识别字幕的代表静帧"
    }
}

enum HardSubtitleRecognizer {
    private struct RecognizedLine {
        let text: String
        let confidence: Double
        let boundingBox: CGRect
    }

    private struct MutableCue {
        var start: Double
        var end: Double
        var text: String
        var confidenceTotal: Double
        var sampleCount: Int
        var shotKeys: [String]

        var cue: HardSubtitleCue {
            HardSubtitleCue(
                start: start,
                end: end,
                text: text,
                confidence: confidenceTotal / Double(max(1, sampleCount)),
                shotKeys: shotKeys
            )
        }
    }

    static func recognize(
        frames: [HardSubtitleFrame],
        progress: @escaping (_ percent: Int) -> Void
    ) throws -> HardSubtitleReadResult {
        guard !frames.isEmpty else {
            throw HardSubtitleRecognizerError.noFrames
        }

        var rawCues: [MutableCue] = []
        let sortedFrames = frames.sorted { $0.start < $1.start }
        for (index, frame) in sortedFrames.enumerated() {
            autoreleasepool {
                if let result = recognize(frame: frame) {
                    append(
                        result: result,
                        frame: frame,
                        to: &rawCues
                    )
                }
            }
            progress(Int((Double(index + 1) / Double(frames.count)) * 100))
        }

        return HardSubtitleReadResult(
            cues: rawCues.map(\.cue),
            scannedShotCount: frames.count
        )
    }

    static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isChineseScalar)
    }

    private static func recognize(frame: HardSubtitleFrame) -> (text: String, confidence: Double)? {
        guard
            frame.imageURL.isFileURL,
            FileManager.default.fileExists(atPath: frame.imageURL.path)
        else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ko-KR", "ja-JP"]

        do {
            try VNImageRequestHandler(url: frame.imageURL).perform([request])
        } catch {
            return nil
        }

        let lines = (request.results ?? []).compactMap { observation -> RecognizedLine? in
            guard
                observation.boundingBox.minY <= 0.58,
                let candidate = observation.topCandidates(1).first,
                candidate.confidence >= 0.34
            else {
                return nil
            }
            let text = cleanLine(candidate.string)
            guard isMeaningfulLine(text) else {
                return nil
            }
            return RecognizedLine(
                text: text,
                confidence: Double(candidate.confidence),
                boundingBox: observation.boundingBox
            )
        }
        .sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.035 {
                return $0.boundingBox.midY > $1.boundingBox.midY
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }

        let textLines = deduped(lines.map(\.text))
        guard !textLines.isEmpty else {
            return nil
        }
        let confidence = lines.map(\.confidence).reduce(0, +) / Double(max(1, lines.count))
        return (
            text: textLines.joined(separator: "\n"),
            confidence: confidence
        )
    }

    private static func append(
        result: (text: String, confidence: Double),
        frame: HardSubtitleFrame,
        to cues: inout [MutableCue]
    ) {
        let normalizedText = normalizedForMerge(result.text)
        if
            var last = cues.last,
            normalizedForMerge(last.text) == normalizedText,
            frame.start - last.end <= 1.2
        {
            last.end = max(last.end, frame.end)
            last.confidenceTotal += result.confidence
            last.sampleCount += 1
            last.shotKeys.append(frame.shotKey)
            cues[cues.count - 1] = last
            return
        }

        cues.append(
            MutableCue(
                start: frame.start,
                end: frame.end,
                text: result.text,
                confidenceTotal: result.confidence,
                sampleCount: 1,
                shotKeys: [frame.shotKey]
            )
        )
    }

    private static func cleanLine(_ value: String) -> String {
        var text = value
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "|·•●○*"))
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isMeaningfulLine(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let lower = text.lowercased()
        if lower.contains("www.") || lower.contains(".com") {
            return false
        }

        var letterCount = 0
        var digitCount = 0
        var hasChinese = false
        for scalar in text.unicodeScalars {
            if isChineseScalar(scalar) {
                hasChinese = true
                letterCount += 1
            } else if CharacterSet.letters.contains(scalar) {
                letterCount += 1
            } else if CharacterSet.decimalDigits.contains(scalar) {
                digitCount += 1
            }
        }

        if hasChinese {
            return letterCount >= 1
        }
        if letterCount >= 2 {
            return true
        }
        return letterCount >= 1 && digitCount >= 1
    }

    private static func deduped(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for line in lines {
            let key = normalizedForMerge(line)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(line)
        }
        return result
    }

    private static func normalizedForMerge(_ text: String) -> String {
        text
            .lowercased()
            .filter { !$0.isWhitespace && !$0.isPunctuation }
            .map(String.init)
            .joined()
    }

    private static func isChineseScalar(_ scalar: Unicode.Scalar) -> Bool {
        (0x3400...0x4DBF).contains(scalar.value)
            || (0x4E00...0x9FFF).contains(scalar.value)
            || (0xF900...0xFAFF).contains(scalar.value)
    }
}
