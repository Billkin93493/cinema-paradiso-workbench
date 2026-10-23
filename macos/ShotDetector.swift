import AVFoundation
import CoreVideo
import Vision

struct LocalShotCandidate {
    let time: Double
    let confidence: Double
    let needsForegroundReview: Bool

    init(
        time: Double,
        confidence: Double,
        needsForegroundReview: Bool = false
    ) {
        self.time = time
        self.confidence = confidence
        self.needsForegroundReview = needsForegroundReview
    }
}

struct LocalShotAnalysis {
    let duration: Double
    let frameCount: Int
    let candidates: [LocalShotCandidate]
}

enum LocalShotDetectorError: LocalizedError {
    case missingVideoTrack
    case cannotReadVideo

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            return "没有读取到可分析的视频画面"
        case .cannotReadVideo:
            return "影片读取失败，请确认文件可以正常播放"
        }
    }
}

enum LocalShotDetector {
    private struct Signature {
        let histogram: [Float]
        let lumaHistogram: [Float]
        let spatialLuma: [Float]
        let spatialPattern: [UInt8]
        let brightness: Float
    }

    private struct PendingCandidate {
        let time: Double
        let score: Float
        let threshold: Float
        let before: Signature
        let needsForegroundReview: Bool
    }

    private struct DistanceMetrics {
        let score: Float
        let distribution: Float
        let spatial: Float
        let pattern: Float
    }

    private struct DetectionState {
        var previousSignature: Signature?
        var pendingCandidate: PendingCandidate?
        var acceptedCandidates: [LocalShotCandidate] = []
        var recentScores: [Float] = []
        var lastReportedPercent = -1
    }

    static func analyze(
        url: URL,
        progress: @escaping (_ percent: Int, _ seconds: Double) -> Void
    ) throws -> LocalShotAnalysis {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw LocalShotDetectorError.missingVideoTrack
        }

        let duration = asset.duration.seconds
        let naturalSize = track.naturalSize
        let longestSide = max(abs(naturalSize.width), abs(naturalSize.height))
        if longestSide > 3840 || (longestSide > 1920 && track.nominalFrameRate > 30) {
            return try analyzeHighResolution(
                asset: asset,
                duration: duration,
                progress: progress
            )
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw LocalShotDetectorError.cannotReadVideo
        }
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? LocalShotDetectorError.cannotReadVideo
        }

        var state = DetectionState()
        var frameCount = 0

        while let sampleBuffer = output.copyNextSampleBuffer() {
            autoreleasepool {
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                let signature = makeSignature(pixelBuffer)
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                frameCount += 1
                process(
                    signature: signature,
                    time: time,
                    duration: duration,
                    state: &state,
                    progress: progress
                )
            }
        }

        finishDetection(state: &state)

        guard reader.status == .completed else {
            throw reader.error ?? LocalShotDetectorError.cannotReadVideo
        }

        state.acceptedCandidates = filterForegroundOcclusions(
            asset: asset,
            candidates: state.acceptedCandidates
        )
        progress(100, duration)
        return LocalShotAnalysis(
            duration: duration,
            frameCount: frameCount,
            candidates: state.acceptedCandidates
        )
    }

    private static func analyzeHighResolution(
        asset: AVAsset,
        duration: Double,
        progress: @escaping (_ percent: Int, _ seconds: Double) -> Void
    ) throws -> LocalShotAnalysis {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 20)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 20)

        var state = DetectionState()
        var frameCount = 0
        var time = 0.0
        while time < duration {
            let requestedTime = CMTime(seconds: time, preferredTimescale: 600)
            let image = try generator.copyCGImage(at: requestedTime, actualTime: nil)
            let signature = makeSignature(image)
            frameCount += 1
            process(
                signature: signature,
                time: time,
                duration: duration,
                state: &state,
                progress: progress
            )
            time += 0.25
        }
        finishDetection(state: &state)
        state.acceptedCandidates = filterForegroundOcclusions(
            asset: asset,
            candidates: state.acceptedCandidates
        )
        progress(100, duration)
        return LocalShotAnalysis(
            duration: duration,
            frameCount: frameCount,
            candidates: state.acceptedCandidates
        )
    }

    private static func process(
        signature: Signature,
        time: Double,
        duration: Double,
        state: inout DetectionState,
        progress: (_ percent: Int, _ seconds: Double) -> Void
    ) {
        guard let previousSignature = state.previousSignature else {
            state.previousSignature = signature
            reportProgress(
                time: time,
                duration: duration,
                lastReportedPercent: &state.lastReportedPercent,
                progress: progress
            )
            return
        }

        let metrics = distance(previousSignature, signature)
        let score = metrics.score
        let adaptiveValue = adaptiveThreshold(state.recentScores)
        let averageBrightness = (previousSignature.brightness + signature.brightness) / 2
        let threshold: Float
        if averageBrightness < 0.08 {
            threshold = min(adaptiveValue, 0.17)
        } else if averageBrightness < 0.18 {
            threshold = min(adaptiveValue, 0.30)
        } else {
            threshold = adaptiveValue
        }
        var suppressCurrentCandidate = false

        if let pendingCandidate = state.pendingCandidate {
            let returnedToPrevious =
                distance(pendingCandidate.before, signature).score < 0.075
            let secondLargeChange = score >= max(0.18, threshold * 0.82)
            if returnedToPrevious && secondLargeChange {
                suppressCurrentCandidate = true
            } else {
                appendCandidate(
                    time: pendingCandidate.time,
                    score: pendingCandidate.score,
                    threshold: pendingCandidate.threshold,
                    needsForegroundReview:
                        pendingCandidate.needsForegroundReview,
                    to: &state.acceptedCandidates
                )
            }
        }

        let needsForegroundReview = shouldReviewForegroundOcclusion(
            metrics: metrics,
            averageBrightness: averageBrightness,
            recentScores: state.recentScores
        )
        let isTransientChange = shouldSuppressTransientChange(
            metrics: metrics,
            averageBrightness: averageBrightness
        )
        if score >= threshold && !suppressCurrentCandidate && !isTransientChange {
            state.pendingCandidate = PendingCandidate(
                time: time,
                score: score,
                threshold: threshold,
                before: previousSignature,
                needsForegroundReview: needsForegroundReview
            )
        } else {
            state.pendingCandidate = nil
        }

        state.recentScores.append(min(score, 0.32))
        if state.recentScores.count > 100 {
            state.recentScores.removeFirst(state.recentScores.count - 100)
        }
        state.previousSignature = signature
        reportProgress(
            time: time,
            duration: duration,
            lastReportedPercent: &state.lastReportedPercent,
            progress: progress
        )
    }

    private static func finishDetection(state: inout DetectionState) {
        guard let pendingCandidate = state.pendingCandidate else { return }
        appendCandidate(
            time: pendingCandidate.time,
            score: pendingCandidate.score,
            threshold: pendingCandidate.threshold,
            needsForegroundReview: pendingCandidate.needsForegroundReview,
            to: &state.acceptedCandidates
        )
        state.pendingCandidate = nil
    }

    private static func reportProgress(
        time: Double,
        duration: Double,
        lastReportedPercent: inout Int,
        progress: (_ percent: Int, _ seconds: Double) -> Void
    ) {
        guard duration > 0 else { return }
        let percent = min(99, max(0, Int((time / duration) * 100)))
        if percent >= lastReportedPercent + 2 {
            lastReportedPercent = percent
            progress(percent, time)
        }
    }

    private static func makeSignature(_ pixelBuffer: CVPixelBuffer) -> Signature {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return emptySignature()
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let columns = 32
        let rows = 18
        var histogram = Array(repeating: Float(0), count: 64)
        var lumaHistogram = Array(repeating: Float(0), count: 32)
        var spatialLuma: [Float] = []
        spatialLuma.reserveCapacity(columns * rows)
        var brightness: Float = 0
        var sampleCount: Float = 0

        for row in 0..<rows {
            let y = min(height - 1, max(0, ((row * 2 + 1) * height) / (rows * 2)))
            for column in 0..<columns {
                let x = min(width - 1, max(0, ((column * 2 + 1) * width) / (columns * 2)))
                let offset = y * bytesPerRow + x * 4
                let blue = bytes[offset]
                let green = bytes[offset + 1]
                let red = bytes[offset + 2]
                let bin = Int(red >> 6) * 16 + Int(green >> 6) * 4 + Int(blue >> 6)
                let luma = (
                    0.2126 * Float(red)
                    + 0.7152 * Float(green)
                    + 0.0722 * Float(blue)
                ) / 255
                histogram[bin] += 1
                lumaHistogram[min(31, Int(luma * 32))] += 1
                spatialLuma.append(luma)
                brightness += luma
                sampleCount += 1
            }
        }

        if sampleCount > 0 {
            histogram = histogram.map { $0 / sampleCount }
            lumaHistogram = lumaHistogram.map { $0 / sampleCount }
            brightness /= sampleCount
        }
        return Signature(
            histogram: histogram,
            lumaHistogram: lumaHistogram,
            spatialLuma: spatialLuma,
            spatialPattern: spatialLuma.map { $0 >= brightness ? 1 : 0 },
            brightness: brightness
        )
    }

    private static func makeSignature(_ image: CGImage) -> Signature {
        let columns = 32
        let rows = 18
        let bytesPerRow = columns * 4
        var pixels = Array(repeating: UInt8(0), count: rows * bytesPerRow)
        pixels.withUnsafeMutableBytes { buffer in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: columns,
                    height: rows,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else {
                return
            }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        }

        var histogram = Array(repeating: Float(0), count: 64)
        var lumaHistogram = Array(repeating: Float(0), count: 32)
        var spatialLuma: [Float] = []
        spatialLuma.reserveCapacity(columns * rows)
        var brightness: Float = 0
        let sampleCount = Float(columns * rows)
        for index in 0..<(columns * rows) {
            let offset = index * 4
            let red = pixels[offset]
            let green = pixels[offset + 1]
            let blue = pixels[offset + 2]
            let bin = Int(red >> 6) * 16 + Int(green >> 6) * 4 + Int(blue >> 6)
            let luma = (
                0.2126 * Float(red)
                + 0.7152 * Float(green)
                + 0.0722 * Float(blue)
            ) / 255
            histogram[bin] += 1
            lumaHistogram[min(31, Int(luma * 32))] += 1
            spatialLuma.append(luma)
            brightness += luma
        }
        histogram = histogram.map { $0 / sampleCount }
        lumaHistogram = lumaHistogram.map { $0 / sampleCount }
        brightness /= sampleCount
        return Signature(
            histogram: histogram,
            lumaHistogram: lumaHistogram,
            spatialLuma: spatialLuma,
            spatialPattern: spatialLuma.map { $0 >= brightness ? 1 : 0 },
            brightness: brightness
        )
    }

    private static func distance(
        _ first: Signature,
        _ second: Signature
    ) -> DistanceMetrics {
        let overlap = zip(first.histogram, second.histogram)
            .reduce(Float(0)) { $0 + min($1.0, $1.1) }
        let histogramDistance = max(0, min(1, 1 - overlap))
        let lumaOverlap = zip(first.lumaHistogram, second.lumaHistogram)
            .reduce(Float(0)) { $0 + min($1.0, $1.1) }
        let lumaHistogramDistance = max(0, min(1, 1 - lumaOverlap))
        let spatialDistance: Float
        if first.spatialLuma.count == second.spatialLuma.count, !first.spatialLuma.isEmpty {
            spatialDistance = zip(first.spatialLuma, second.spatialLuma)
                .reduce(Float(0)) { $0 + abs($1.0 - $1.1) }
                / Float(first.spatialLuma.count)
        } else {
            spatialDistance = 0
        }
        let patternDistance: Float
        if first.spatialPattern.count == second.spatialPattern.count,
           !first.spatialPattern.isEmpty
        {
            let mismatches = zip(first.spatialPattern, second.spatialPattern)
                .reduce(0) { $0 + ($1.0 == $1.1 ? 0 : 1) }
            patternDistance = Float(mismatches) / Float(first.spatialPattern.count)
        } else {
            patternDistance = 0
        }
        let brightnessDistance = min(1, abs(first.brightness - second.brightness) * 2.2)
        let distributionDistance = histogramDistance * 0.62
            + lumaHistogramDistance * 0.28
            + brightnessDistance * 0.10
        let averageBrightness = (first.brightness + second.brightness) / 2
        let spatialMultiplier: Float
        if averageBrightness < 0.18 {
            spatialMultiplier = 6.0
        } else if averageBrightness < 0.30 {
            spatialMultiplier = 4.2
        } else {
            spatialMultiplier = 3.4
        }
        let patternMultiplier: Float = averageBrightness < 0.18 ? 1.15 : 0.72
        let spatialScore = min(1, spatialDistance * spatialMultiplier)
        let patternScore = min(1, patternDistance * patternMultiplier)
        return DistanceMetrics(
            score: max(distributionDistance, spatialScore, patternScore),
            distribution: distributionDistance,
            spatial: spatialScore,
            pattern: patternScore
        )
    }

    private static func shouldSuppressTransientChange(
        metrics: DistanceMetrics,
        averageBrightness: Float
    ) -> Bool {
        let lightingOnlyChange =
            averageBrightness < 0.08
            && metrics.distribution >= metrics.spatial
            && metrics.pattern < 0.12
            && metrics.distribution - metrics.pattern > 0.14

        return lightingOnlyChange
    }

    private static func shouldReviewForegroundOcclusion(
        metrics: DistanceMetrics,
        averageBrightness: Float,
        recentScores: [Float]
    ) -> Bool {
        let recentWindow = recentScores.suffix(12)
        let recentMean = recentWindow.isEmpty
            ? 0
            : recentWindow.reduce(0, +) / Float(recentWindow.count)
        let recentElevatedCount = recentWindow.filter { $0 >= 0.12 }.count
        let spatiallyDominant =
            averageBrightness >= 0.18
            && metrics.distribution < 0.34
            && metrics.pattern < 0.24
            && metrics.spatial > metrics.distribution * 1.7
            && metrics.spatial > metrics.pattern * 1.7
        guard spatiallyDominant else { return false }

        let sustainedMotion =
            recentMean > 0.20
            && recentElevatedCount >= 9
        let subtleOcclusion =
            metrics.distribution < 0.14
            && metrics.pattern < 0.20
            && recentMean > 0.06
            && recentElevatedCount >= 3
        return sustainedMotion || subtleOcclusion
    }

    private static func filterForegroundOcclusions(
        asset: AVAsset,
        candidates: [LocalShotCandidate]
    ) -> [LocalShotCandidate] {
        guard candidates.contains(where: \.needsForegroundReview) else {
            return candidates
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        return candidates.filter { candidate in
            guard candidate.needsForegroundReview else { return true }
            do {
                return try !isContinuousForegroundMotion(
                    at: candidate.time,
                    generator: generator
                )
            } catch {
                return true
            }
        }
    }

    private static func isContinuousForegroundMotion(
        at time: Double,
        generator: AVAssetImageGenerator
    ) throws -> Bool {
        let offset = 0.12
        let farBefore = try featurePrint(
            frame(generator, at: max(0, time - offset * 3))
        )
        let before = try featurePrint(
            frame(generator, at: max(0, time - offset))
        )
        let after = try featurePrint(
            frame(generator, at: time + offset)
        )
        let farAfter = try featurePrint(
            frame(generator, at: time + offset * 3)
        )
        let beforeMotion = try featureDistance(farBefore, before)
        let cutDistance = try featureDistance(before, after)
        let afterMotion = try featureDistance(after, farAfter)
        let motionRatio =
            cutDistance / max(0.01, (beforeMotion + afterMotion) / 2)

        return motionRatio < 2.05
            || (
                beforeMotion > 0.25
                && afterMotion > 0.25
                && motionRatio < 3.0
            )
    }

    private static func frame(
        _ generator: AVAssetImageGenerator,
        at seconds: Double
    ) throws -> CGImage {
        try generator.copyCGImage(
            at: CMTime(seconds: seconds, preferredTimescale: 600),
            actualTime: nil
        )
    }

    private static func featurePrint(
        _ image: CGImage
    ) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let result = request.results?.first as? VNFeaturePrintObservation else {
            throw LocalShotDetectorError.cannotReadVideo
        }
        return result
    }

    private static func featureDistance(
        _ first: VNFeaturePrintObservation,
        _ second: VNFeaturePrintObservation
    ) throws -> Float {
        var value: Float = 0
        try first.computeDistance(&value, to: second)
        return value
    }

    private static func emptySignature() -> Signature {
        Signature(
            histogram: Array(repeating: 0, count: 64),
            lumaHistogram: Array(repeating: 0, count: 32),
            spatialLuma: [],
            spatialPattern: [],
            brightness: 0
        )
    }

    private static func adaptiveThreshold(_ recentScores: [Float]) -> Float {
        guard recentScores.count >= 20 else { return 0.28 }
        let mean = recentScores.reduce(0, +) / Float(recentScores.count)
        let variance = recentScores.reduce(Float(0)) {
            let delta = $1 - mean
            return $0 + delta * delta
        } / Float(recentScores.count)
        let deviation = sqrt(variance)
        return min(0.62, max(0.19, mean + max(0.105, deviation * 4.2)))
    }

    private static func appendCandidate(
        time: Double,
        score: Float,
        threshold: Float,
        needsForegroundReview: Bool,
        to candidates: inout [LocalShotCandidate]
    ) {
        guard time > 0.2 else { return }
        let confidence = min(0.99, max(0.58, 0.58 + Double((score - threshold) / max(0.08, 1 - threshold)) * 0.41))
        let candidate = LocalShotCandidate(
            time: time,
            confidence: confidence,
            needsForegroundReview: needsForegroundReview
        )

        if let last = candidates.last, time - last.time < 0.32 {
            if confidence > last.confidence {
                candidates[candidates.count - 1] = candidate
            }
            return
        }
        candidates.append(candidate)
    }
}
