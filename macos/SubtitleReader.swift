import AVFoundation
import CoreFoundation
import CoreMedia
import Foundation

struct SubtitleCue {
    let start: Double
    let end: Double
    let text: String

    var bridgeValue: [String: Any] {
        [
            "start": start,
            "end": end,
            "text": text,
        ]
    }
}

struct SubtitleReadResult {
    let found: Bool
    let sourceType: String
    let sourceName: String
    let language: String
    let isChinese: Bool
    let candidateCount: Int
    let cues: [SubtitleCue]
    let scannedAt: String

    var bridgeValue: [String: Any] {
        [
            "found": found,
            "sourceType": sourceType,
            "sourceName": sourceName,
            "language": language,
            "isChinese": isChinese,
            "candidateCount": candidateCount,
            "cueCount": cues.count,
            "cues": cues.map(\.bridgeValue),
            "scannedAt": scannedAt,
        ]
    }
}

enum ExistingSubtitleReader {
    private struct Candidate {
        let sourceType: String
        let sourceName: String
        let language: String
        let isChinese: Bool
        let cues: [SubtitleCue]
    }

    static func read(videoURL: URL) -> SubtitleReadResult {
        let externalCandidates = readExternalCandidates(videoURL: videoURL)
        let embeddedCandidates = readEmbeddedCandidates(videoURL: videoURL)
        let candidates = externalCandidates + embeddedCandidates
        let selected = candidates.first(where: \.isChinese) ?? candidates.first
        let scannedAt = ISO8601DateFormatter().string(from: Date())

        guard let selected else {
            return SubtitleReadResult(
                found: false,
                sourceType: "none",
                sourceName: "",
                language: "",
                isChinese: false,
                candidateCount: 0,
                cues: [],
                scannedAt: scannedAt
            )
        }

        return SubtitleReadResult(
            found: true,
            sourceType: selected.sourceType,
            sourceName: selected.sourceName,
            language: selected.language,
            isChinese: selected.isChinese,
            candidateCount: candidates.count,
            cues: selected.cues,
            scannedAt: scannedAt
        )
    }

    private static func readExternalCandidates(videoURL: URL) -> [Candidate] {
        let directoryURL = videoURL.deletingLastPathComponent()
        let videoBaseName = videoURL.deletingPathExtension().lastPathComponent
        guard
            let files = try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return files
            .filter { matches(videoBaseName: videoBaseName, subtitleURL: $0) }
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }
            .compactMap { url in
                guard
                    let text = decodeSubtitleFile(at: url),
                    let cues = parseExternalSubtitle(text, extension: url.pathExtension.lowercased()),
                    !cues.isEmpty
                else {
                    return nil
                }
                let language = inferredLanguage(
                    languageCode: nil,
                    sourceName: url.deletingPathExtension().lastPathComponent,
                    cues: cues
                )
                return Candidate(
                    sourceType: "external",
                    sourceName: url.lastPathComponent,
                    language: language,
                    isChinese: isChinese(language: language, sourceName: url.lastPathComponent, cues: cues),
                    cues: cues
                )
            }
    }

    private static func matches(videoBaseName: String, subtitleURL: URL) -> Bool {
        let supported = ["srt", "ass", "ssa", "vtt"]
        guard supported.contains(subtitleURL.pathExtension.lowercased()) else {
            return false
        }
        let base = videoBaseName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let subtitleBase = subtitleURL
            .deletingPathExtension()
            .lastPathComponent
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard subtitleBase.hasPrefix(base) else { return false }
        if subtitleBase == base { return true }
        let suffix = subtitleBase.dropFirst(base.count)
        return [".", "-", "_", " "].contains(where: { suffix.hasPrefix($0) })
    }

    private static func decodeSubtitleFile(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            stringEncoding(.GB_18030_2000),
            stringEncoding(.big5),
            .windowsCP1252,
            .isoLatin1,
        ]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding), !text.isEmpty {
                return text
            }
        }
        return nil
    }

    private static func stringEncoding(_ encoding: CFStringEncodings) -> String.Encoding {
        String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(encoding.rawValue)
            )
        )
    }

    private static func parseExternalSubtitle(_ text: String, extension fileExtension: String) -> [SubtitleCue]? {
        switch fileExtension {
        case "srt":
            return parseSRT(text)
        case "ass", "ssa":
            return parseASS(text)
        case "vtt":
            return parseVTT(text)
        default:
            return nil
        }
    }

    private static func parseSRT(_ text: String) -> [SubtitleCue] {
        parseBlockSubtitle(text, allowCueSettings: true)
    }

    private static func parseVTT(_ text: String) -> [SubtitleCue] {
        let normalized = normalizedNewlines(text)
        let blocks = normalized.components(separatedBy: "\n\n")
        return blocks.compactMap { block in
            let lines = block
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard
                !lines.isEmpty,
                lines.first?.uppercased().hasPrefix("WEBVTT") != true,
                lines.first?.uppercased().hasPrefix("NOTE") != true,
                let timeIndex = lines.firstIndex(where: { $0.contains("-->") }),
                let times = parseTimeRange(lines[timeIndex], allowCueSettings: true)
            else {
                return nil
            }
            let content = cleanCueText(lines.dropFirst(timeIndex + 1).joined(separator: "\n"))
            guard !content.isEmpty else { return nil }
            return SubtitleCue(start: times.start, end: times.end, text: content)
        }
    }

    private static func parseBlockSubtitle(_ text: String, allowCueSettings: Bool) -> [SubtitleCue] {
        let normalized = normalizedNewlines(text)
        return normalized.components(separatedBy: "\n\n").compactMap { block in
            let lines = block
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard
                let timeIndex = lines.firstIndex(where: { $0.contains("-->") }),
                let times = parseTimeRange(lines[timeIndex], allowCueSettings: allowCueSettings)
            else {
                return nil
            }
            let content = cleanCueText(lines.dropFirst(timeIndex + 1).joined(separator: "\n"))
            guard !content.isEmpty else { return nil }
            return SubtitleCue(start: times.start, end: times.end, text: content)
        }
    }

    private static func parseASS(_ text: String) -> [SubtitleCue] {
        let lines = normalizedNewlines(text).components(separatedBy: "\n")
        var inEvents = false
        var fields = ["layer", "start", "end", "style", "name", "marginl", "marginr", "marginv", "effect", "text"]
        var cues: [SubtitleCue] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("[") && line.hasSuffix("]") {
                inEvents = line.lowercased() == "[events]"
                continue
            }
            guard inEvents else { continue }
            if line.lowercased().hasPrefix("format:") {
                fields = line
                    .dropFirst(line.firstIndex(of: ":").map { line.distance(from: line.startIndex, to: $0) + 1 } ?? 0)
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                continue
            }
            guard line.lowercased().hasPrefix("dialogue:") else { continue }
            let value = String(line.dropFirst("dialogue:".count))
            let parts = value.split(separator: ",", maxSplits: max(0, fields.count - 1), omittingEmptySubsequences: false)
            guard
                let startIndex = fields.firstIndex(of: "start"),
                let endIndex = fields.firstIndex(of: "end"),
                let textIndex = fields.firstIndex(of: "text"),
                parts.indices.contains(startIndex),
                parts.indices.contains(endIndex),
                parts.indices.contains(textIndex),
                let start = parseTimestamp(String(parts[startIndex])),
                let end = parseTimestamp(String(parts[endIndex])),
                end > start
            else {
                continue
            }
            let content = cleanCueText(String(parts[textIndex]))
            if !content.isEmpty {
                cues.append(SubtitleCue(start: start, end: end, text: content))
            }
        }
        return cues
    }

    private static func parseTimeRange(
        _ line: String,
        allowCueSettings: Bool
    ) -> (start: Double, end: Double)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return nil }
        let startText = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let endText: String
        if allowCueSettings {
            endText = parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isWhitespace)
                .first
                .map(String.init) ?? ""
        } else {
            endText = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard
            let start = parseTimestamp(startText),
            let end = parseTimestamp(endText),
            end > start
        else {
            return nil
        }
        return (start, end)
    }

    private static func parseTimestamp(_ value: String) -> Double? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ":")
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let seconds = Double(parts.last ?? "") ?? -1
        let minutes = Double(parts[parts.count - 2]) ?? -1
        let hours = parts.count == 3 ? (Double(parts[0]) ?? -1) : 0
        guard hours >= 0, minutes >= 0, seconds >= 0 else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }

    private static func readEmbeddedCandidates(videoURL: URL) -> [Candidate] {
        let asset = AVURLAsset(url: videoURL)
        let tracks = asset.tracks.filter {
            $0.mediaType == .subtitle || $0.mediaType == .text
        }
        return tracks.enumerated().compactMap { index, track in
            guard let cues = readEmbeddedTrack(asset: asset, track: track), !cues.isEmpty else {
                return nil
            }
            let language = inferredLanguage(
                languageCode: track.extendedLanguageTag ?? track.languageCode,
                sourceName: "",
                cues: cues
            )
            return Candidate(
                sourceType: "embedded",
                sourceName: "影片内置字幕 \(index + 1)",
                language: language,
                isChinese: isChinese(language: language, sourceName: "", cues: cues),
                cues: cues
            )
        }
    }

    private static func readEmbeddedTrack(asset: AVAsset, track: AVAssetTrack) -> [SubtitleCue]? {
        guard let reader = try? AVAssetReader(asset: asset) else { return nil }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }

        let subtype = track.formatDescriptions.first.map {
            CMFormatDescriptionGetMediaSubType($0 as! CMFormatDescription)
        }
        var entries: [(start: Double, duration: Double?, text: String)] = []

        while let sample = output.copyNextSampleBuffer() {
            let start = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard start.isFinite, let data = sampleData(sample) else { continue }
            let text = cleanCueText(decodeEmbeddedText(data: data, subtype: subtype))
            guard !text.isEmpty else { continue }
            let rawDuration = CMSampleBufferGetDuration(sample).seconds
            let duration = rawDuration.isFinite && rawDuration > 0 ? rawDuration : nil
            entries.append((start, duration, text))
        }

        return entries.enumerated().compactMap { index, entry in
            let nextStart = entries.indices.contains(index + 1) ? entries[index + 1].start : nil
            let fallbackEnd = nextStart ?? (entry.start + 2)
            let end = entry.duration.map { entry.start + $0 } ?? fallbackEnd
            guard end > entry.start else { return nil }
            return SubtitleCue(start: entry.start, end: end, text: entry.text)
        }
    }

    private static func sampleData(_ sample: CMSampleBuffer) -> Data? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sample) else { return nil }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        guard length > 0 else { return nil }
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return kCMBlockBufferBadCustomBlockSourceErr }
            return CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: length,
                destination: baseAddress
            )
        }
        return status == noErr ? data : nil
    }

    private static func decodeEmbeddedText(data: Data, subtype: FourCharCode?) -> String {
        if subtype == kCMSubtitleFormatType_WebVTT {
            let payloads = boxPayloads(named: fourCC("payl"), in: data)
            return payloads.compactMap(decodeTextData).joined(separator: "\n")
        }
        if
            subtype == kCMSubtitleFormatType_3GText
                || subtype == kCMTextFormatType_3GText
                || subtype == kCMTextFormatType_QTText,
            data.count >= 2
        {
            let length = Int(data[data.startIndex]) << 8 | Int(data[data.startIndex + 1])
            if length > 0, data.count >= length + 2 {
                return decodeTextData(data.subdata(in: 2..<(length + 2))) ?? ""
            }
        }
        return decodeTextData(data) ?? ""
    }

    private static func boxPayloads(named target: FourCharCode, in data: Data) -> [Data] {
        var payloads: [Data] = []
        var offset = 0
        while offset + 8 <= data.count {
            let size = Int(readUInt32(data, offset: offset))
            let type = readUInt32(data, offset: offset + 4)
            guard size >= 8, offset + size <= data.count else { break }
            let payload = data.subdata(in: (offset + 8)..<(offset + size))
            if type == target {
                payloads.append(payload)
            } else if type == fourCC("vttc") {
                payloads.append(contentsOf: boxPayloads(named: target, in: payload))
            }
            offset += size
        }
        return payloads
    }

    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private static func fourCC(_ value: String) -> FourCharCode {
        value.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
    }

    private static func decodeTextData(_ data: Data) -> String? {
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16BigEndian)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data, encoding: .utf16LittleEndian)
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
    }

    private static func inferredLanguage(
        languageCode: String?,
        sourceName: String,
        cues: [SubtitleCue]
    ) -> String {
        let normalizedCode = languageCode?.lowercased() ?? ""
        if isChineseLanguageCode(normalizedCode) {
            return normalizedCode.isEmpty ? "zh" : normalizedCode
        }
        let lowerName = sourceName.lowercased()
        if chineseNameHints.contains(where: { lowerName.contains($0) }) {
            return "zh"
        }
        if cues.prefix(40).contains(where: { containsChinese($0.text) }) {
            return "zh"
        }
        if !normalizedCode.isEmpty {
            return normalizedCode
        }
        if englishNameHints.contains(where: { lowerName.contains($0) }) {
            return "en"
        }
        return ""
    }

    private static func isChinese(
        language: String,
        sourceName: String,
        cues: [SubtitleCue]
    ) -> Bool {
        isChineseLanguageCode(language)
            || chineseNameHints.contains(where: { sourceName.lowercased().contains($0) })
            || cues.prefix(40).contains(where: { containsChinese($0.text) })
    }

    private static func isChineseLanguageCode(_ value: String) -> Bool {
        let code = value.lowercased()
        return code == "zh"
            || code.hasPrefix("zh-")
            || code == "chi"
            || code == "zho"
            || code == "cmn"
    }

    private static let chineseNameHints = [
        ".zh", "_zh", "-zh", " zh",
        ".chs", "_chs", "-chs",
        ".cht", "_cht", "-cht",
        ".chi", "_chi", "-chi",
        ".zho", "_zho", "-zho",
        ".cn", "_cn", "-cn",
        "中文", "简体", "繁体",
    ]

    private static let englishNameHints = [
        ".en", "_en", "-en", " eng", ".eng", "_eng", "-eng",
    ]

    private static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            (0x3400...0x4DBF).contains($0.value)
                || (0x4E00...0x9FFF).contains($0.value)
                || (0xF900...0xFAFF).contains($0.value)
        }
    }

    private static func normalizedNewlines(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func cleanCueText<S: StringProtocol>(_ value: S) -> String {
        var text = String(value)
        text = text
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\h", with: " ")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(
            of: "\\{[^}]*\\}",
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        return text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
