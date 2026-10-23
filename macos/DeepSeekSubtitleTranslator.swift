import Foundation

struct SubtitleTranslationCue {
    let id: Int
    let text: String
}

struct SubtitleTranslationOutcome {
    let model: String
    let translations: [Int: String]
    let requestedCount: Int
    let errorMessage: String?

    var bridgeValue: [String: Any] {
        var value: [String: Any] = [
            "provider": "deepseek",
            "model": model,
            "requestedCount": requestedCount,
            "translatedCount": translations.count,
            "translations": translations
                .sorted { $0.key < $1.key }
                .map { ["id": $0.key, "text": $0.value] },
        ]
        if let errorMessage {
            value["error"] = errorMessage
        }
        return value
    }
}

struct DeepSeekSubtitleTranslator {
    typealias RequestExecutor = (URLRequest) async throws -> (Data, URLResponse)

    private let endpoint: URL
    private let model: String
    private let maxBatchItems: Int
    private let maxBatchCharacters: Int
    private let execute: RequestExecutor

    init(
        endpoint: URL = URL(string: "https://api.deepseek.com/chat/completions")!,
        model: String = "deepseek-v4-flash",
        maxBatchItems: Int = 60,
        maxBatchCharacters: Int = 12_000,
        execute: @escaping RequestExecutor = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.endpoint = endpoint
        self.model = model
        self.maxBatchItems = max(1, maxBatchItems)
        self.maxBatchCharacters = max(500, maxBatchCharacters)
        self.execute = execute
    }

    func translate(
        cues: [SubtitleTranslationCue],
        apiKey: String,
        progress: ((Int, Int) -> Void)? = nil
    ) async -> SubtitleTranslationOutcome {
        let validCues = cues.filter {
            $0.id >= 0 && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !validCues.isEmpty else {
            return SubtitleTranslationOutcome(
                model: model,
                translations: [:],
                requestedCount: 0,
                errorMessage: "没有可翻译的英文字幕"
            )
        }

        let batches = makeBatches(validCues)
        var translations: [Int: String] = [:]

        for batch in batches {
            do {
                let translatedBatch = try await translateBatch(batch, apiKey: apiKey)
                translatedBatch.forEach { translations[$0.key] = $0.value }
                progress?(translations.count, validCues.count)
            } catch {
                return SubtitleTranslationOutcome(
                    model: model,
                    translations: translations,
                    requestedCount: validCues.count,
                    errorMessage: userMessage(for: error)
                )
            }
        }

        let missingCount = validCues.count - translations.count
        return SubtitleTranslationOutcome(
            model: model,
            translations: translations,
            requestedCount: validCues.count,
            errorMessage: missingCount > 0 ? "有 \(missingCount) 条字幕没有返回译文，可以重新翻译" : nil
        )
    }

    private func makeBatches(_ cues: [SubtitleTranslationCue]) -> [[SubtitleTranslationCue]] {
        var batches: [[SubtitleTranslationCue]] = []
        var current: [SubtitleTranslationCue] = []
        var characterCount = 0

        for cue in cues {
            let cueCount = cue.text.count
            if
                !current.isEmpty
                    && (current.count >= maxBatchItems || characterCount + cueCount > maxBatchCharacters)
            {
                batches.append(current)
                current = []
                characterCount = 0
            }
            current.append(cue)
            characterCount += cueCount
        }
        if !current.isEmpty {
            batches.append(current)
        }
        return batches
    }

    private func translateBatch(
        _ cues: [SubtitleTranslationCue],
        apiKey: String
    ) async throws -> [Int: String] {
        let subtitlePayload = cues.map { ["id": $0.id, "text": $0.text] as [String: Any] }
        let subtitleData = try JSONSerialization.data(
            withJSONObject: ["subtitles": subtitlePayload],
            options: []
        )
        let subtitleJSON = String(data: subtitleData, encoding: .utf8) ?? "{}"
        let body: [String: Any] = [
            "model": model,
            "thinking": ["type": "disabled"],
            "temperature": 0.1,
            "response_format": ["type": "json_object"],
            "messages": [
                [
                    "role": "system",
                    "content": """
                    你是专业影视字幕翻译。把英文字幕准确、自然、简洁地翻译成简体中文。
                    保留人物语气、称谓、双关和影视语境，不添加解释，不合并或拆分字幕。
                    只返回 JSON：{"translations":[{"id":原编号,"text":"中文译文"}]}。
                    """,
                ],
                [
                    "role": "user",
                    "content": subtitleJSON,
                ],
            ],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await execute(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TranslationError.httpStatus(httpResponse.statusCode)
        }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw TranslationError.invalidResponse
        }
        return try parseTranslations(content, expectedIDs: Set(cues.map(\.id)))
    }

    private func parseTranslations(_ content: String, expectedIDs: Set<Int>) throws -> [Int: String] {
        let cleaned = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "^```(?:json)?\\s*|\\s*```$",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        guard
            let data = cleaned.data(using: .utf8),
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = root["translations"] as? [[String: Any]]
        else {
            throw TranslationError.invalidTranslation
        }

        var translations: [Int: String] = [:]
        for item in items {
            let id = item["id"] as? Int
                ?? (item["id"] as? NSNumber)?.intValue
            let text = (item["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let id, expectedIDs.contains(id), let text, !text.isEmpty {
                translations[id] = text
            }
        }
        guard !translations.isEmpty else {
            throw TranslationError.invalidTranslation
        }
        return translations
    }

    private func userMessage(for error: Error) -> String {
        if let translationError = error as? TranslationError {
            switch translationError {
            case .httpStatus(401):
                return "DeepSeek 密钥无效，请更换后重试"
            case .httpStatus(402):
                return "DeepSeek 账户余额不足，请充值后重试"
            case .httpStatus(429):
                return "DeepSeek 请求过于频繁，请稍后重试"
            case .httpStatus(500), .httpStatus(503):
                return "DeepSeek 服务暂时繁忙，请稍后重试"
            case .httpStatus:
                return "DeepSeek 翻译没有完成，请稍后重试"
            case .invalidResponse, .invalidTranslation:
                return "翻译结果格式异常，英文原文已保留，可以重新翻译"
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "网络连接中断，英文原文已保留"
            case .timedOut:
                return "翻译等待超时，英文原文已保留，可以重试"
            default:
                return "网络请求失败，英文原文已保留"
            }
        }
        return "翻译没有完成，英文原文已保留，可以重试"
    }

    private enum TranslationError: Error {
        case httpStatus(Int)
        case invalidResponse
        case invalidTranslation
    }
}
