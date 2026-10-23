import AppKit
import AVFoundation

@main
struct CutComparisonProbe {
    static func main() throws {
        guard CommandLine.arguments.count >= 4 else {
            throw NSError(
                domain: "CutComparisonProbe",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "用法：CutComparisonProbe 影片路径 切点秒数列表 输出图片"
                ]
            )
        }

        let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let cutTimes = CommandLine.arguments[2]
            .split(separator: ",")
            .compactMap { Double($0) }
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
        guard !cutTimes.isEmpty else {
            throw NSError(
                domain: "CutComparisonProbe",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "没有可抽查的切点"]
            )
        }

        let frameWidth = 640
        let frameHeight = 360
        let labelHeight = 42
        let rowHeight = frameHeight + labelHeight
        let canvas = NSImage(
            size: NSSize(width: frameWidth * 2, height: rowHeight * cutTimes.count)
        )
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: frameWidth, height: frameHeight)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        canvas.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: canvas.size).fill()

        for (index, cutTime) in cutTimes.enumerated() {
            for (column, offset) in [-0.12, 0.12].enumerated() {
                let seconds = max(0, cutTime + offset)
                let image = try generator.copyCGImage(
                    at: CMTime(seconds: seconds, preferredTimescale: 600),
                    actualTime: nil
                )
                let x = column * frameWidth
                let y = (cutTimes.count - 1 - index) * rowHeight + labelHeight
                NSImage(cgImage: image, size: .zero).draw(
                    in: NSRect(x: x, y: y, width: frameWidth, height: frameHeight)
                )
                let side = column == 0 ? "切点前" : "切点后"
                "\(timecode(seconds)) · \(side)".draw(
                    at: NSPoint(x: x + 12, y: y - 30),
                    withAttributes: [
                        .foregroundColor: NSColor.white,
                        .font: NSFont.monospacedDigitSystemFont(
                            ofSize: 20,
                            weight: .medium
                        ),
                    ]
                )
            }
        }
        canvas.unlockFocus()

        guard
            let tiff = canvas.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(
                domain: "CutComparisonProbe",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "无法生成切点抽查图"]
            )
        }
        try png.write(to: outputURL, options: .atomic)
        print(outputURL.path)
    }

    private static func timecode(_ seconds: Double) -> String {
        let totalMilliseconds = max(0, Int((seconds * 1000).rounded()))
        let totalSeconds = totalMilliseconds / 1000
        return String(
            format: "%02d:%02d:%02d.%03d",
            totalSeconds / 3600,
            (totalSeconds % 3600) / 60,
            totalSeconds % 60,
            totalMilliseconds % 1000
        )
    }
}
