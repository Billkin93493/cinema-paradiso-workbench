import AVFoundation
import CoreMedia
import Foundation

@main
struct SubtitleReaderWorkflowTest {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("tmp/subtitle-reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let mixedFolder = root.appendingPathComponent("mixed", isDirectory: true)
        try FileManager.default.createDirectory(at: mixedFolder, withIntermediateDirectories: true)
        let mixedVideo = mixedFolder.appendingPathComponent("测试影片.mp4")
        try Data().write(to: mixedVideo)
        try """
        1
        00:00:01,000 --> 00:00:03,500
        This is the English subtitle.

        2
        00:00:04,000 --> 00:00:06,000
        Second line.
        """.write(
            to: mixedFolder.appendingPathComponent("测试影片.en.srt"),
            atomically: true,
            encoding: .utf8
        )
        try """
        [Script Info]
        Title: 测试

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.20,0:00:03.80,Default,,0,0,0,,{\\an8}这是中文字幕
        Dialogue: 0,0:00:04.00,0:00:06.00,Default,,0,0,0,,第二句\\N换行
        """.write(
            to: mixedFolder.appendingPathComponent("测试影片.zh-CN.ass"),
            atomically: true,
            encoding: .utf8
        )
        try """
        1
        00:00:00,000 --> 00:00:01,000
        不应读取其他影片字幕
        """.write(
            to: mixedFolder.appendingPathComponent("其他影片.zh.srt"),
            atomically: true,
            encoding: .utf8
        )

        let mixed = ExistingSubtitleReader.read(videoURL: mixedVideo)
        guard
            mixed.found,
            mixed.isChinese,
            mixed.sourceName == "测试影片.zh-CN.ass",
            mixed.candidateCount == 2,
            mixed.cues.count == 2,
            mixed.cues[0].text == "这是中文字幕",
            mixed.cues[1].text == "第二句\n换行"
        else {
            throw NSError(domain: "SubtitleReaderTest", code: 1)
        }

        let vttFolder = root.appendingPathComponent("vtt", isDirectory: true)
        try FileManager.default.createDirectory(at: vttFolder, withIntermediateDirectories: true)
        let vttVideo = vttFolder.appendingPathComponent("短片.mov")
        try Data().write(to: vttVideo)
        try """
        WEBVTT

        intro
        00:00:02.000 --> 00:00:04.250 align:start
        <i>Hello</i> world
        """.write(
            to: vttFolder.appendingPathComponent("短片.vtt"),
            atomically: true,
            encoding: .utf8
        )
        let vtt = ExistingSubtitleReader.read(videoURL: vttVideo)
        guard
            vtt.found,
            vtt.sourceName == "短片.vtt",
            vtt.cues.count == 1,
            vtt.cues[0].text == "Hello world",
            abs(vtt.cues[0].start - 2) < 0.001,
            abs(vtt.cues[0].end - 4.25) < 0.001
        else {
            throw NSError(domain: "SubtitleReaderTest", code: 2)
        }

        let emptyFolder = root.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
        let emptyVideo = emptyFolder.appendingPathComponent("无字幕.mp4")
        try Data().write(to: emptyVideo)
        let empty = ExistingSubtitleReader.read(videoURL: emptyVideo)
        guard !empty.found, empty.cues.isEmpty else {
            throw NSError(domain: "SubtitleReaderTest", code: 3)
        }

        let embeddedFolder = root.appendingPathComponent("embedded", isDirectory: true)
        try FileManager.default.createDirectory(at: embeddedFolder, withIntermediateDirectories: true)
        let embeddedVideo = embeddedFolder.appendingPathComponent("内置字幕.mov")
        try writeEmbeddedSubtitleMovie(to: embeddedVideo)
        let embedded = ExistingSubtitleReader.read(videoURL: embeddedVideo)
        guard
            embedded.found,
            embedded.sourceType == "embedded",
            embedded.isChinese,
            embedded.cues.count == 2,
            embedded.cues[0].text == "第一条内置字幕",
            embedded.cues[1].text == "第二条内置字幕"
        else {
            throw NSError(domain: "SubtitleReaderTest", code: 4)
        }

        print(
            "SUBTITLE_READER_TEST_OK source=\(mixed.sourceName) cues=\(mixed.cues.count) vtt=\(vtt.cues.count) embedded=\(embedded.cues.count)"
        )
    }

    private static func writeEmbeddedSubtitleMovie(to url: URL) throws {
        let transparentColor: [CFString: Any] = [
            kCMTextFormatDescriptionColor_Red: 0,
            kCMTextFormatDescriptionColor_Green: 0,
            kCMTextFormatDescriptionColor_Blue: 0,
            kCMTextFormatDescriptionColor_Alpha: 0,
        ]
        let whiteColor: [CFString: Any] = [
            kCMTextFormatDescriptionColor_Red: 255,
            kCMTextFormatDescriptionColor_Green: 255,
            kCMTextFormatDescriptionColor_Blue: 255,
            kCMTextFormatDescriptionColor_Alpha: 255,
        ]
        let extensions: [CFString: Any] = [
            kCMTextFormatDescriptionExtension_DisplayFlags: 0,
            kCMTextFormatDescriptionExtension_HorizontalJustification: 0,
            kCMTextFormatDescriptionExtension_VerticalJustification: 0,
            kCMTextFormatDescriptionExtension_BackgroundColor: transparentColor,
            kCMTextFormatDescriptionExtension_DefaultTextBox: [
                kCMTextFormatDescriptionRect_Top: 0,
                kCMTextFormatDescriptionRect_Left: 0,
                kCMTextFormatDescriptionRect_Bottom: 0,
                kCMTextFormatDescriptionRect_Right: 0,
            ],
            kCMTextFormatDescriptionExtension_DefaultStyle: [
                kCMTextFormatDescriptionStyle_StartChar: 0,
                kCMTextFormatDescriptionStyle_EndChar: 0,
                kCMTextFormatDescriptionStyle_Font: 1,
                kCMTextFormatDescriptionStyle_FontFace: 0,
                kCMTextFormatDescriptionStyle_FontSize: 18,
                kCMTextFormatDescriptionStyle_ForegroundColor: whiteColor,
            ],
            kCMTextFormatDescriptionExtension_FontTable: ["1": "Helvetica"],
        ]
        var formatDescription: CMFormatDescription?
        let formatStatus = CMFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            mediaType: kCMMediaType_Text,
            mediaSubType: kCMTextFormatType_3GText,
            extensions: extensions as CFDictionary,
            formatDescriptionOut: &formatDescription
        )
        guard formatStatus == noErr, let formatDescription else {
            throw NSError(domain: "SubtitleReaderTest", code: 10)
        }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .text,
            outputSettings: nil,
            sourceFormatHint: formatDescription
        )
        input.languageCode = "zho"
        guard writer.canAdd(input) else {
            throw NSError(domain: "SubtitleReaderTest", code: 11)
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "SubtitleReaderTest", code: 12)
        }
        writer.startSession(atSourceTime: .zero)
        guard
            input.append(
                try subtitleSample(
                    text: "第一条内置字幕",
                    start: CMTime(seconds: 1, preferredTimescale: 1000),
                    duration: CMTime(seconds: 2, preferredTimescale: 1000),
                    formatDescription: formatDescription
                )
            ),
            input.append(
                try subtitleSample(
                    text: "第二条内置字幕",
                    start: CMTime(seconds: 4, preferredTimescale: 1000),
                    duration: CMTime(seconds: 2, preferredTimescale: 1000),
                    formatDescription: formatDescription
                )
            )
        else {
            throw writer.error ?? NSError(domain: "SubtitleReaderTest", code: 13)
        }
        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()
        guard writer.status == .completed else {
            throw writer.error ?? NSError(domain: "SubtitleReaderTest", code: 14)
        }
    }

    private static func subtitleSample(
        text: String,
        start: CMTime,
        duration: CMTime,
        formatDescription: CMFormatDescription
    ) throws -> CMSampleBuffer {
        let textData = Data(text.utf8)
        var bytes = Data([
            UInt8((textData.count >> 8) & 0xFF),
            UInt8(textData.count & 0xFF),
        ])
        bytes.append(textData)

        var blockBuffer: CMBlockBuffer?
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: bytes.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: bytes.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard blockStatus == kCMBlockBufferNoErr, let blockBuffer else {
            throw NSError(domain: "SubtitleReaderTest", code: 15)
        }
        let replaceStatus = bytes.withUnsafeBytes { rawBytes in
            CMBlockBufferReplaceDataBytes(
                with: rawBytes.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: bytes.count
            )
        }
        guard replaceStatus == kCMBlockBufferNoErr else {
            throw NSError(domain: "SubtitleReaderTest", code: 16)
        }

        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: start,
            decodeTimeStamp: .invalid
        )
        var sampleSize = bytes.count
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer else {
            throw NSError(domain: "SubtitleReaderTest", code: 17)
        }
        return sampleBuffer
    }
}
