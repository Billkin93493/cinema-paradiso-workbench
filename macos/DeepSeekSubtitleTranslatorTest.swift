import Foundation

@main
struct DeepSeekSubtitleTranslatorTest {
    static func main() async throws {
        try await testSuccessfulBatches()
        try await testPartialFailure()
        try await testInvalidKey()
        print("DEEPSEEK_SUBTITLE_TRANSLATOR_TEST_OK")
    }

    private static func testSuccessfulBatches() async throws {
        var requestBodies: [[String: Any]] = []
        let translator = DeepSeekSubtitleTranslator(maxBatchItems: 2) { request in
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as! [String: Any]
            requestBodies.append(body)
            let messages = body["messages"] as! [[String: Any]]
            let userContent = messages[1]["content"] as! String
            let payloadData = userContent.data(using: .utf8)!
            let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]
            let subtitles = payload["subtitles"] as! [[String: Any]]
            let translations = subtitles.map {
                ["id": $0["id"]!, "text": "中文-\($0["id"]!)"]
            }
            return try response(
                status: 200,
                content: ["translations": translations]
            )
        }
        var progressValues: [Int] = []
        let result = await translator.translate(
            cues: [
                SubtitleTranslationCue(id: 0, text: "Hello."),
                SubtitleTranslationCue(id: 1, text: "How are you?"),
                SubtitleTranslationCue(id: 2, text: "Goodbye."),
            ],
            apiKey: "sk-test-only"
        ) { translated, _ in
            progressValues.append(translated)
        }

        guard
            result.errorMessage == nil,
            result.translations.count == 3,
            result.translations[1] == "中文-1",
            requestBodies.count == 2,
            progressValues == [2, 3],
            requestBodies.allSatisfy({ $0["model"] as? String == "deepseek-v4-flash" }),
            requestBodies.allSatisfy({
                (($0["thinking"] as? [String: Any])?["type"] as? String) == "disabled"
            })
        else {
            throw NSError(domain: "DeepSeekSubtitleTranslatorTest", code: 1)
        }
    }

    private static func testPartialFailure() async throws {
        var requestCount = 0
        let translator = DeepSeekSubtitleTranslator(maxBatchItems: 1) { request in
            requestCount += 1
            if requestCount == 2 {
                return (
                    Data(),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 503,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
            return try response(
                status: 200,
                content: ["translations": [["id": 0, "text": "第一句"]]]
            )
        }
        let result = await translator.translate(
            cues: [
                SubtitleTranslationCue(id: 0, text: "First."),
                SubtitleTranslationCue(id: 1, text: "Second."),
            ],
            apiKey: "sk-test-only"
        )
        guard
            result.translations == [0: "第一句"],
            result.errorMessage == "DeepSeek 服务暂时繁忙，请稍后重试"
        else {
            throw NSError(domain: "DeepSeekSubtitleTranslatorTest", code: 2)
        }
    }

    private static func testInvalidKey() async throws {
        let translator = DeepSeekSubtitleTranslator { request in
            (
                Data(),
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        }
        let result = await translator.translate(
            cues: [SubtitleTranslationCue(id: 0, text: "Hello.")],
            apiKey: "sk-invalid"
        )
        guard
            result.translations.isEmpty,
            result.errorMessage == "DeepSeek 密钥无效，请更换后重试"
        else {
            throw NSError(domain: "DeepSeekSubtitleTranslatorTest", code: 3)
        }
    }

    private static func response(
        status: Int,
        content: [String: Any]
    ) throws -> (Data, URLResponse) {
        let contentData = try JSONSerialization.data(withJSONObject: content)
        let contentText = String(data: contentData, encoding: .utf8)!
        let data = try JSONSerialization.data(
            withJSONObject: [
                "choices": [
                    ["message": ["content": contentText]],
                ],
            ]
        )
        return (
            data,
            HTTPURLResponse(
                url: URL(string: "https://api.deepseek.com/chat/completions")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}
