import XCTest
@testable import StoryTime

final class APIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.storytime.session-token")
        defaults.removeObject(forKey: "com.storytime.session-expiry")
    }

    override func tearDown() {
        URLProtocolStub.reset()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.storytime.session-token")
        defaults.removeObject(forKey: "com.storytime.session-expiry")
        super.tearDown()
    }

    func testPrepareConnectionFallsBackToHealthyBaseURLAndCachesIt() async throws {
        let session = makeSession()
        let first = URL(string: "https://one.example.com/")!
        let second = URL(string: "https://two.example.com/")!
        var requests: [String] = []

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            requests.append(url.absoluteString)
            if url.host == "one.example.com" {
                throw URLError(.cannotConnectToHost)
            }

            return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])
        }

        let client = APIClient(baseURLs: [first, second], session: session, installId: "install-123")

        let resolved = try await client.prepareConnection()
        let cached = try await client.prepareConnection()

        XCTAssertEqual(resolved, second)
        XCTAssertEqual(cached, second)
        XCTAssertEqual(requests.filter { $0 == "https://one.example.com/health" }.count, 1)
        XCTAssertEqual(requests.filter { $0 == "https://two.example.com/health" }.count, 2)
    }

    func testFetchVoicesFallsBackOnDecodeError() async throws {
        let session = makeSession()
        let first = URL(string: "https://one.example.com/")!
        let second = URL(string: "https://two.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-install-id"), "install-xyz")
            if url.host == "one.example.com" {
                return Self.rawResponse(url: url, statusCode: 200, body: "not-json")
            }

            return try Self.httpResponse(url: url, statusCode: 200, json: ["language": "en", "voices": ["alloy", "verse"]])
        }

        let client = APIClient(baseURLs: [first, second], session: session, installId: "install-xyz")
        let voices = try await client.fetchVoices()

        XCTAssertEqual(voices, ["alloy", "verse"])
    }

    func testCreateRealtimeSessionBootstrapsIdentityAndSendsSessionHeader() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var sawRealtimeSessionHeader = false

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            switch url.path {
            case "/v1/session/identity":
                XCTAssertEqual(request.httpMethod, "POST")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-1"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/realtime/session":
                sawRealtimeSessionHeader = request.value(forHTTPHeaderField: "x-storytime-session") == "signed-session-token"
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-123",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )
            default:
                return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let response = try await client.createRealtimeSession(
            request: RealtimeSessionRequest(
                childProfileId: "child-1",
                voice: "alloy",
                region: "US"
            )
        )

        XCTAssertEqual(response.session.ticket, "ticket-123")
        XCTAssertEqual(AppSession.currentToken, "signed-session-token")
        XCTAssertTrue(sawRealtimeSessionHeader)
    }

    func testCreateRealtimeSessionContinuesWhenLegacyBackendLacksIdentityBootstrap() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var sawRealtimeSessionRequest = false

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(url: url, statusCode: 404, json: ["error": "missing"])
            case "/v1/realtime/session":
                sawRealtimeSessionRequest = true
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-session"))
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-legacy",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )
            default:
                return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-legacy")
        let response = try await client.createRealtimeSession(
            request: RealtimeSessionRequest(
                childProfileId: "child-legacy",
                voice: "alloy",
                region: "US"
            )
        )

        XCTAssertTrue(sawRealtimeSessionRequest)
        XCTAssertEqual(response.session.ticket, "ticket-legacy")
        XCTAssertNil(AppSession.currentToken)
    }

    func testStoryEndpointsDecodeBlocked422ResponsesAndEmbeddings() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let defaults = UserDefaults.standard
        defaults.set("existing-session-token", forKey: "com.storytime.session-token")
        defaults.set(Date().addingTimeInterval(300).timeIntervalSince1970, forKey: "com.storytime.session-expiry")

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "existing-session-token")

            switch url.path {
            case "/v1/story/discovery":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 422,
                    json: [
                        "blocked": true,
                        "safe_message": "Let's keep it gentle.",
                        "data": [
                            "slot_state": [
                                "theme": "",
                                "characters": [],
                                "setting": "",
                                "tone": "",
                                "episode_intent": ""
                            ],
                            "question_count": 1,
                            "ready_to_generate": false,
                            "assistant_message": "Try a friendly idea.",
                            "transcript": "too scary"
                        ]
                    ]
                )
            case "/v1/story/generate":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 422,
                    json: [
                        "blocked": true,
                        "safe_message": "Let's try a softer story idea.",
                        "data": Self.storyJSON(storyId: "blocked-story", title: "Gentle Story")
                    ]
                )
            case "/v1/story/revise":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 422,
                    json: [
                        "blocked": true,
                        "safe_message": "Let's keep the ending friendly.",
                        "data": [
                            "story_id": "story-1",
                            "revised_from_scene_index": 1,
                            "scenes": [
                                ["scene_id": "2", "text": "A softer ending arrived.", "duration_sec": 40]
                            ],
                            "safety": [
                                "input_moderation": "pass",
                                "output_moderation": "pass"
                            ],
                            "engine": NSNull()
                        ]
                    ]
                )
            case "/v1/embeddings/create":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["embeddings": [[0.1, 0.2], [0.3, 0.4]]]
                )
            default:
                return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let discovery = try await client.discoverStoryTurn(
            request: DiscoveryRequest(
                childProfileId: "child-1",
                transcript: "too scary",
                questionCount: 1,
                slotState: DiscoverySlotState(),
                mode: "new",
                previousEpisodeRecap: nil
            )
        )
        let generated = try await client.generateStory(
            request: GenerateStoryRequest(
                childProfileId: "child-1",
                ageBand: "3-8",
                language: "en",
                lengthMinutes: 4,
                voice: "alloy",
                questionCount: 1,
                storyBrief: StoryBrief(
                    theme: "gentle bedtime",
                    characters: ["Bunny"],
                    setting: "park",
                    tone: "soft",
                    episodeIntent: "standalone",
                    lesson: nil
                ),
                continuityFacts: []
            )
        )
        let revised = try await client.reviseStory(
            request: ReviseStoryRequest(
                storyId: "story-1",
                currentSceneIndex: 1,
                storyTitle: "Gentle Story",
                userUpdate: "Make it softer",
                completedScenes: [],
                remainingScenes: [StoryScene(sceneId: "2", text: "Old ending", durationSec: 40)]
            )
        )
        let embeddings = try await client.createEmbeddings(inputs: ["Bunny", "Fox"])

        XCTAssertTrue(discovery.blocked)
        XCTAssertTrue(generated.blocked)
        XCTAssertTrue(revised.blocked)
        XCTAssertEqual(embeddings.count, 2)
    }

    func testInvalidResponsesAndSessionTokenLifecycle() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path == "/v1/voices" {
                return try Self.httpResponse(url: url, statusCode: 500, json: ["error": "boom"])
            }
            return Self.rawResponse(url: url, statusCode: 200, body: "ok")
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")

        do {
            _ = try await client.fetchVoices()
            XCTFail("Expected fetchVoices to fail")
        } catch let error as APIError {
            switch error {
            case .invalidResponse(let statusCode, let body):
                XCTAssertEqual(statusCode, 500)
                XCTAssertTrue(body.contains("boom"))
            case .connectionFailed:
                XCTFail("Expected invalidResponse")
            }
        }

        let expiry = Date().addingTimeInterval(-10).timeIntervalSince1970
        UserDefaults.standard.set("expired-token", forKey: "com.storytime.session-token")
        UserDefaults.standard.set(expiry, forKey: "com.storytime.session-expiry")
        XCTAssertNil(AppSession.currentToken)

        let response = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "x-storytime-session": "fresh-token",
                "x-storytime-session-expires-at": String(Date().addingTimeInterval(200).timeIntervalSince1970)
            ]
        )!
        AppSession.store(from: response)
        XCTAssertEqual(AppSession.currentToken, "fresh-token")
        AppSession.clear()
        XCTAssertNil(AppSession.currentToken)
        XCTAssertTrue(APIError.connectionFailed([baseURL]).localizedDescription.contains("Could not connect"))
    }

    func testFetchVoicesRetriesOn404FromFirstBaseURL() async throws {
        let session = makeSession()
        let first = URL(string: "https://one.example.com/")!
        let second = URL(string: "https://two.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.host == "one.example.com" {
                return try Self.httpResponse(url: url, statusCode: 404, json: ["error": "missing"])
            }
            return try Self.httpResponse(url: url, statusCode: 200, json: ["language": "en", "voices": ["alloy"]])
        }

        let client = APIClient(baseURLs: [first, second], session: session, installId: "install-123")
        let voices = try await client.fetchVoices()

        XCTAssertEqual(voices, ["alloy"])
    }

    func testFetchVoicesFailsWhenResponseIsNotHTTP() async {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            return (URLResponse(url: url, mimeType: "application/json", expectedContentLength: 0, textEncodingName: nil), Data())
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")

        do {
            _ = try await client.fetchVoices()
            XCTFail("Expected a connection failure")
        } catch let error as APIError {
            switch error {
            case .connectionFailed(let candidates):
                XCTAssertEqual(candidates, [baseURL])
            case .invalidResponse:
                XCTFail("Expected connectionFailed for a non-HTTP response")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPrepareConnectionWithoutCandidateBaseURLsThrowsConnectionFailed() async {
        let client = APIClient(baseURLs: [], session: makeSession(), installId: "install-123")

        do {
            _ = try await client.prepareConnection()
            XCTFail("Expected connection failure")
        } catch let error as APIError {
            switch error {
            case .connectionFailed(let candidates):
                XCTAssertTrue(candidates.isEmpty)
            case .invalidResponse:
                XCTFail("Expected connection failure")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private static func storyJSON(storyId: String, title: String) -> [String: Any] {
        [
            "story_id": storyId,
            "title": title,
            "estimated_duration_sec": 90,
            "scenes": [
                ["scene_id": "1", "text": "A gentle scene", "duration_sec": 45]
            ],
            "safety": [
                "input_moderation": "pass",
                "output_moderation": "pass"
            ],
            "engine": NSNull()
        ]
    }

    private static func httpResponse(
        url: URL,
        statusCode: Int,
        json: Any,
        headers: [String: String] = [:]
    ) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
        return (response, data)
    }

    private static func rawResponse(url: URL, statusCode: Int, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (URLResponse, Data))?

    static func reset() {
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
