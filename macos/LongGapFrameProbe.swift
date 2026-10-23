import AppKit
import AVFoundation

@main
struct LongGapFrameProbe {
    static func main() throws {
        guard CommandLine.arguments.count >= 5 else {
            throw NSError(
                domain: "LongGapFrameProbe",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "用法：LongGapFrameProbe 影片路径 开始秒数 结束秒数 输出图片"
                ]
            )
        }

        let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let start = Double(CommandLine.arguments[2]) ?? 0
        let end = Double(CommandLine.arguments[3]) ?? start
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[4])
        let columns = 4
        let rows = 3
        let frameWidth = 480
        let frameHeight = 270
        let labelHeight = 30
        let canvas = NSImage(
            size: NSSize(
                width: columns * frameWidth,
                height: rows * (frameHeight + labelHeight)
            )
        )
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: frameWidth, height: frameHeight)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        canvas.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: canvas.size).fill()
        for index in 0..<(columns * rows) {
            let ratio = Double(index) / Double(columns * rows - 1)
            let seconds = start + (end - start) * ratio
            let image = try generator.copyCGImage(
                at: CMTime(seconds: seconds, preferredTimescale: 600),
                actualTime: nil
            )
            let column = index % columns
            let row = rows - 1 - index / columns
            let x = column * frameWidth
            let y = row * (frameHeight + labelHeight) + labelHeight
            NSImage(cgImage: image, size: .zero).draw(
                in: NSRect(x: x, y: y, width: frameWidth, height: frameHeight)
            )
            let label = timecode(seconds)
            label.draw(
                at: NSPoint(x: x + 10, y: y - 23),
                withAttributes: [
                    .foregroundColor: NSColor.white,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium),
                ]
            )
        }
        canvas.unlockFocus()

        guard
            let tiff = canvas.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(
                domain: "LongGapFrameProbe",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法生成抽查图"]
            )
        }
        try png.write(to: outputURL, options: .atomic)
        print(outputURL.path)
    }

    private static func timecode(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(
            format: "%02d:%02d:%02d",
            total / 3600,
            (total % 3600) / 60,
            total % 60
        )
    }
}
