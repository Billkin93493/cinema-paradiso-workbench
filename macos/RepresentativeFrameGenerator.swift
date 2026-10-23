import AppKit
import AVFoundation

struct RepresentativeFrameResult {
    let shotKey: String
    let capturedAt: Double
    let imageURL: URL
    let source: String

    var bridgeValue: [String: Any] {
        [
            "shotKey": shotKey,
            "capturedAt": capturedAt,
            "imageUrl": imageURL.absoluteString,
            "source": source,
        ]
    }
}

enum RepresentativeFrameGeneratorError: LocalizedError {
    case noFrames
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .noFrames:
            return "没有取得可用的镜头画面"
        case .invalidImage:
            return "当前画面无法保存"
        }
    }
}

enum RepresentativeFrameGenerator {
    struct Shot {
        let key: String
        let start: Double
        let end: Double
    }

    private struct Candidate {
        let shotKey: String
        let time: Double
    }

    static func generate(
        videoURL: URL,
        shots: [Shot],
        rootDirectoryURL: URL,
        progress: @escaping (_ percent: Int) -> Void
    ) throws -> [String: RepresentativeFrameResult] {
        guard !shots.isEmpty else { return [:] }

        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = NSSize(width: 640, height: 360)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.08, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.08, preferredTimescale: 600)

        let candidates = shots.flatMap(candidateFrames)
        let groupedCandidates = Dictionary(grouping: candidates) { timeKey($0.time) }
        let requestedTimes = groupedCandidates.values.compactMap { group -> NSValue? in
            guard let time = group.first?.time else { return nil }
            return NSValue(time: CMTime(seconds: time, preferredTimescale: 600))
        }

        let lock = NSLock()
        let group = DispatchGroup()
        var imagesByShot: [String: [(time: Double, image: CGImage)]] = [:]
        var completed = 0

        requestedTimes.forEach { _ in group.enter() }
        generator.generateCGImagesAsynchronously(forTimes: requestedTimes) {
            requestedTime,
            image,
            _,
            _,
            _ in
            defer { group.leave() }
            let key = timeKey(requestedTime.seconds)
            lock.lock()
            if let image, let matches = groupedCandidates[key] {
                for candidate in matches {
                    imagesByShot[candidate.shotKey, default: []].append((candidate.time, image))
                }
            }
            completed += 1
            let percent = Int((Double(completed) / Double(max(1, requestedTimes.count))) * 100)
            lock.unlock()
            progress(percent)
        }
        group.wait()

        let destinationURL = projectDirectory(
            rootDirectoryURL: rootDirectoryURL,
            sourcePath: videoURL.path
        )
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true
        )

        var results: [String: RepresentativeFrameResult] = [:]
        for shot in shots {
            var best = imagesByShot[shot.key]?.max {
                frameScore($0.image) < frameScore($1.image)
            }
            if best == nil {
                let fallbackTime = shot.start + max(0, shot.end - shot.start) * 0.5
                var actualTime = CMTime.invalid
                if let image = try? generator.copyCGImage(
                    at: CMTime(seconds: fallbackTime, preferredTimescale: 600),
                    actualTime: &actualTime
                ) {
                    let capturedAt = actualTime.seconds.isFinite
                        ? actualTime.seconds
                        : fallbackTime
                    best = (capturedAt, image)
                }
            }
            guard let best else { continue }
            let imageURL = destinationURL.appendingPathComponent("\(safeFileName(shot.key)).jpg")
            try jpegData(from: best.image).write(to: imageURL, options: .atomic)
            results[shot.key] = RepresentativeFrameResult(
                shotKey: shot.key,
                capturedAt: best.time,
                imageURL: imageURL,
                source: "auto"
            )
        }

        guard !results.isEmpty else {
            throw RepresentativeFrameGeneratorError.noFrames
        }
        return results
    }

    static func saveManualFrame(
        imageDataURL: String,
        shotKey: String,
        capturedAt: Double,
        sourcePath: String,
        rootDirectoryURL: URL
    ) throws -> RepresentativeFrameResult {
        guard
            let encodedImage = imageDataURL.split(separator: ",", maxSplits: 1).last,
            let imageData = Data(base64Encoded: String(encodedImage))
        else {
            throw RepresentativeFrameGeneratorError.invalidImage
        }

        let destinationURL = projectDirectory(
            rootDirectoryURL: rootDirectoryURL,
            sourcePath: sourcePath
        )
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true
        )
        let imageURL = destinationURL.appendingPathComponent("\(safeFileName(shotKey)).jpg")
        try imageData.write(to: imageURL, options: .atomic)
        return RepresentativeFrameResult(
            shotKey: shotKey,
            capturedAt: capturedAt,
            imageURL: imageURL,
            source: "manual"
        )
    }

    private static func candidateFrames(for shot: Shot) -> [Candidate] {
        let duration = max(0, shot.end - shot.start)
        guard duration > 0 else { return [] }
        let inset = min(0.18, duration * 0.12)
        let usableStart = shot.start + inset
        let usableEnd = max(usableStart, shot.end - inset)
        let usableDuration = usableEnd - usableStart
        let fractions: [Double] = duration < 0.24 ? [0.5] : [0.25, 0.5, 0.75]
        return fractions.map {
            Candidate(shotKey: shot.key, time: usableStart + usableDuration * $0)
        }
    }

    private static func frameScore(_ image: CGImage) -> Double {
        let width = 64
        let height = 36
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
            return 0
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luminance = [Double](repeating: 0, count: width * height)
        var total = 0.0
        for index in 0..<(width * height) {
            let offset = index * 4
            let value = (
                0.2126 * Double(pixels[offset])
                + 0.7152 * Double(pixels[offset + 1])
                + 0.0722 * Double(pixels[offset + 2])
            ) / 255
            luminance[index] = value
            total += value
        }

        let mean = total / Double(luminance.count)
        let variance = luminance.reduce(0) { result, value in
            let delta = value - mean
            return result + delta * delta
        } / Double(luminance.count)

        var edgeTotal = 0.0
        var edgeCount = 0
        for y in 1..<height {
            for x in 1..<width {
                let index = y * width + x
                edgeTotal += abs(luminance[index] - luminance[index - 1])
                edgeTotal += abs(luminance[index] - luminance[index - width])
                edgeCount += 2
            }
        }
        let sharpness = edgeTotal / Double(max(1, edgeCount))
        let exposurePenalty = mean < 0.08
            ? (0.08 - mean) * 2.5
            : (mean > 0.92 ? (mean - 0.92) * 2.5 : 0)
        return sharpness * 2.2 + sqrt(variance) * 0.85 - exposurePenalty
    }

    private static func jpegData(from image: CGImage) throws -> Data {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.84]
        ) else {
            throw RepresentativeFrameGeneratorError.invalidImage
        }
        return data
    }

    private static func projectDirectory(
        rootDirectoryURL: URL,
        sourcePath: String
    ) -> URL {
        rootDirectoryURL
            .appendingPathComponent("representative-frames", isDirectory: true)
            .appendingPathComponent(stableIdentifier(sourcePath), isDirectory: true)
    }

    private static func stableIdentifier(_ value: String) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private static func safeFileName(_ value: String) -> String {
        value.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
                ? character
                : "_"
        }.reduce(into: "") { $0.append($1) }
    }

    private static func timeKey(_ seconds: Double) -> String {
        String(Int((seconds * 600).rounded()))
    }
}
