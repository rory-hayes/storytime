import XCTest
@testable import StoryTime

@MainActor
final class RealtimeVoiceClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.storytime.session-token")
        defaults.removeObject(forKey: "com.storytime.session-expiry")
        defaults.removeObject(forKey: "com.storytime.session-id")
        defaults.removeObject(forKey: "com.storytime.session-region")
    }

    func testSpeakCancelAndDisconnectSendCommandsOnceBridgeIsReady() async {
        let client = RealtimeVoiceClient()
        var commands: [(String, [String: Any])] = []
        client.bridgeCommandSender = { command, payload in
            commands.append((command, payload))
        }
        client.setBridgeReadyForTesting()

        await client.speak(text: "Hello there", utteranceId: "utterance-1")
        await client.cancelAssistantSpeech()
        await client.disconnect()

        XCTAssertEqual(commands.map(\.0), ["speak", "cancel", "disconnect"])
        XCTAssertEqual(commands.first?.1["text"] as? String, "Hello there")
        XCTAssertEqual(commands.first?.1["utteranceId"] as? String, "utterance-1")
    }

    func testCommandsBeforeBridgeReadyAndBlankSpeechDoNotSendAnything() async {
        let client = RealtimeVoiceClient()
        var commands: [(String, [String: Any])] = []
        client.bridgeCommandSender = { command, payload in
            commands.append((command, payload))
        }

        await client.speak(text: "   ")
        await client.cancelAssistantSpeech()
        await client.disconnect()

        XCTAssertTrue(commands.isEmpty)
    }

    func testConnectBuildsPayloadAndResumesOnConnectedBridgeEvent() async throws {
        let client = RealtimeVoiceClient()
        let defaults = UserDefaults.standard
        defaults.set("session-token-123", forKey: "com.storytime.session-token")
        defaults.set(Date().addingTimeInterval(60).timeIntervalSince1970, forKey: "com.storytime.session-expiry")

        var sentCommand: String?
        var sentPayload: [String: Any] = [:]
        client.bridgeCommandSender = { command, payload in
            sentCommand = command
            sentPayload = payload
        }
        client.setBridgeReadyForTesting()

        let connectTask = Task {
            try await client.connect(
                baseURL: URL(string: "https://backend.example.com/mobile/")!,
                endpointPath: "/v1/realtime/call",
                session: RealtimeSessionData(
                    ticket: "signed-ticket",
                    expiresAt: 120,
                    model: "gpt-realtime",
                    voice: "alloy",
                    inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
                ),
                installId: "install-123"
            )
        }

        await Task.yield()
        client.handleBridgeMessageForTesting(["type": "connected"])
        try await connectTask.value

        XCTAssertEqual(sentCommand, "connect")
        XCTAssertEqual(sentPayload["ticket"] as? String, "signed-ticket")
        XCTAssertEqual(sentPayload["installId"] as? String, "install-123")
        XCTAssertEqual(sentPayload["sessionToken"] as? String, "session-token-123")
        XCTAssertEqual(sentPayload["callURL"] as? String, "https://backend.example.com/v1/realtime/call")
        XCTAssertNil(sentPayload["baseURL"])
    }

    func testConnectWaitsForBridgeReadyBeforeSendingStartupCommand() async throws {
        let client = RealtimeVoiceClient()
        var sendCount = 0
        let connectSent = expectation(description: "connect command sent after bridge ready")
        client.bridgeCommandSender = { command, _ in
            XCTAssertEqual(command, "connect")
            sendCount += 1
            connectSent.fulfill()
        }
        client.bridgeReadyTimeoutNanoseconds = 500_000_000

        let connectTask = Task {
            try await client.connect(
                baseURL: URL(string: "https://backend.example.com")!,
                endpointPath: "/v1/realtime/call",
                session: RealtimeSessionData(
                    ticket: "signed-ticket",
                    expiresAt: 120,
                    model: "gpt-realtime",
                    voice: "alloy",
                    inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
                ),
                installId: "install-123"
            )
        }

        await Task.yield()
        XCTAssertEqual(sendCount, 0)

        client.setBridgeReadyForTesting()
        await fulfillment(of: [connectSent], timeout: 1.0)
        client.handleBridgeMessageForTesting(["type": "connected"])
        try await connectTask.value

        XCTAssertEqual(sendCount, 1)
    }

    func testConnectAcceptsAbsoluteEndpointPathAndEmptySessionToken() async throws {
        let client = RealtimeVoiceClient()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.storytime.session-token")
        defaults.removeObject(forKey: "com.storytime.session-expiry")

        var sentPayload: [String: Any] = [:]
        client.bridgeCommandSender = { _, payload in
            sentPayload = payload
        }
        client.setBridgeReadyForTesting()

        let connectTask = Task {
            try await client.connect(
                baseURL: URL(string: "https://backend.example.com")!,
                endpointPath: "https://edge.example.com/v1/realtime/call",
                session: RealtimeSessionData(
                    ticket: "signed-ticket",
                    expiresAt: 120,
                    model: "gpt-realtime",
                    voice: "alloy",
                    inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
                ),
                installId: "install-123"
            )
        }

        await Task.yield()
        client.handleBridgeMessageForTesting(["type": "connected"])
        try await connectTask.value

        XCTAssertEqual(sentPayload["callURL"] as? String, "https://edge.example.com/v1/realtime/call")
        XCTAssertEqual(sentPayload["sessionToken"] as? String, "")
    }

    func testConnectResolvesPathRelativeEndpointAgainstBasePath() async throws {
        let client = RealtimeVoiceClient()
        var sentPayload: [String: Any] = [:]
        client.bridgeCommandSender = { _, payload in
            sentPayload = payload
        }
        client.setBridgeReadyForTesting()

        let connectTask = Task {
            try await client.connect(
                baseURL: URL(string: "https://backend.example.com/mobile/")!,
                endpointPath: "v1/realtime/call",
                session: RealtimeSessionData(
                    ticket: "signed-ticket",
                    expiresAt: 120,
                    model: "gpt-realtime",
                    voice: "alloy",
                    inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
                ),
                installId: "install-123"
            )
        }

        await Task.yield()
        client.handleBridgeMessageForTesting(["type": "connected"])
        try await connectTask.value

        XCTAssertEqual(sentPayload["callURL"] as? String, "https://backend.example.com/mobile/v1/realtime/call")
    }

    func testConnectFailsWhenBridgeReportsAnError() async {
        let client = RealtimeVoiceClient()
        client.bridgeCommandSender = { _, _ in }
        client.setBridgeReadyForTesting()

        let connectTask = Task {
            do {
                try await client.connect(
                    baseURL: URL(string: "https://backend.example.com")!,
                    endpointPath: "/v1/realtime/call",
                    session: RealtimeSessionData(
                        ticket: "signed-ticket",
                        expiresAt: 120,
                        model: "gpt-realtime",
                        voice: "alloy",
                        inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
                    ),
                    installId: "install-123"
                )
                XCTFail("Expected connect to fail")
            } catch {
                XCTAssertTrue(error.localizedDescription.contains("Socket failed"))
            }
        }

        await Task.yield()
        client.handleBridgeMessageForTesting(["type": "error", "message": "Socket failed"])
        await connectTask.value
    }

    func testConnectWaitsForBridgeReadyAndFailsOnDisconnect() async {
        let client = RealtimeVoiceClient()
        client.bridgeCommandSender = { _, _ in }
        client.setBridgeReadyForTesting()

        let connectTask = Task {
            do {
                try await client.connect(
                    baseURL: URL(string: "https://backend.example.com")!,
                    endpointPath: "/v1/realtime/call",
                    session: RealtimeSessionData(
                        ticket: "signed-ticket",
                        expiresAt: 120,
                        model: "gpt-realtime",
                        voice: "alloy",
                        inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
                    ),
                    installId: "install-123"
                )
                XCTFail("Expected connect to fail")
            } catch {
                XCTAssertTrue(error.localizedDescription.contains("invalid response"))
            }
        }

        await Task.yield()
        client.handleBridgeMessageForTesting(["type": "disconnected"])
        await connectTask.value
    }

    func testConnectFailsWhenBridgeNeverBecomesReadyBeforeTimeout() async {
        let client = RealtimeVoiceClient()
        client.bridgeCommandSender = { _, _ in }
        client.bridgeReadyTimeoutNanoseconds = 60_000_000

        let connectTask = Task {
            do {
                try await client.connect(
                    baseURL: URL(string: "https://backend.example.com")!,
                    endpointPath: "/v1/realtime/call",
                    session: RealtimeSessionData(
                        ticket: "signed-ticket",
                        expiresAt: 120,
                        model: "gpt-realtime",
                        voice: "alloy",
                        inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
                    ),
                    installId: "install-123"
                )
                XCTFail("Expected connect to fail")
            } catch {
                XCTAssertEqual(
                    error as? RealtimeVoiceClient.RealtimeError,
                    .bridgeReadyTimedOut
                )
            }
        }

        await connectTask.value
    }

    func testConnectFailsWhenBridgeDisconnectsBeforeReady() async {
        let client = RealtimeVoiceClient()
        client.bridgeCommandSender = { _, _ in }
        client.bridgeReadyTimeoutNanoseconds = 500_000_000

        let connectTask = Task {
            do {
                try await client.connect(
                    baseURL: URL(string: "https://backend.example.com")!,
                    endpointPath: "/v1/realtime/call",
                    session: RealtimeSessionData(
                        ticket: "signed-ticket",
                        expiresAt: 120,
                        model: "gpt-realtime",
                        voice: "alloy",
                        inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
                    ),
                    installId: "install-123"
                )
                XCTFail("Expected connect to fail")
            } catch {
                XCTAssertEqual(
                    error as? RealtimeVoiceClient.RealtimeError,
                    .disconnectedBeforeReady
                )
            }
        }

        await Task.yield()
        client.handleBridgeMessageForTesting(["type": "disconnected"])
        await connectTask.value
    }

    func testConnectFailsWhenBridgeNavigationFailsBeforeReady() async {
        let client = RealtimeVoiceClient()
        client.bridgeCommandSender = { _, _ in }
        client.bridgeReadyTimeoutNanoseconds = 500_000_000

        let connectTask = Task {
            do {
                try await client.connect(
                    baseURL: URL(string: "https://backend.example.com")!,
                    endpointPath: "/v1/realtime/call",
                    session: RealtimeSessionData(
                        ticket: "signed-ticket",
                        expiresAt: 120,
                        model: "gpt-realtime",
                        voice: "alloy",
                        inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
                    ),
                    installId: "install-123"
                )
                XCTFail("Expected connect to fail")
            } catch {
                XCTAssertEqual(
                    error as? RealtimeVoiceClient.RealtimeError,
                    .bridgeReadyFailed("Bridge navigation failed")
                )
            }
        }

        await Task.yield()
        client.webView(
            client.webView,
            didFailProvisionalNavigation: nil,
            withError: NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorCannotFindHost,
                userInfo: [NSLocalizedDescriptionKey: "Bridge navigation failed"]
            )
        )
        await connectTask.value
    }

    func testBridgeMessagesFanOutToCallbacks() {
        let client = RealtimeVoiceClient()
        var partial = ""
        var final = ""
        var localLevel: CGFloat = 0
        var remoteLevel: CGFloat = 0
        var userSpeaking = false
        var connectedCount = 0
        var disconnectedCount = 0
        var completionID: String?
        var receivedError = ""

        client.onConnected = { connectedCount += 1 }
        client.onDisconnected = { disconnectedCount += 1 }
        client.onTranscriptPartial = { partial = $0 }
        client.onTranscriptFinal = { final = $0 }
        client.onLevels = { local, remote in
            localLevel = local
            remoteLevel = remote
        }
        client.onUserSpeechChanged = { userSpeaking = $0 }
        client.onAssistantResponseCompleted = { completionID = $0 }
        client.onError = { receivedError = $0 }

        client.handleBridgeMessageForTesting(["type": "connected"])
        client.handleBridgeMessageForTesting(["type": "levels", "localLevel": 0.1, "remoteLevel": 0.4])
        client.handleBridgeMessageForTesting(["type": "user_speech_state", "speaking": true])
        client.handleBridgeMessageForTesting(["type": "transcript_partial", "text": "Bunny wants"])
        client.handleBridgeMessageForTesting(["type": "transcript_final", "text": "Bunny wants a lantern adventure"])
        client.handleBridgeMessageForTesting(["type": "assistant_response_completed", "utteranceId": "utterance-7"])
        client.handleBridgeMessageForTesting(["type": "error", "message": "Bridge problem"])
        client.handleBridgeMessageForTesting(["type": "disconnected"])

        XCTAssertEqual(connectedCount, 1)
        XCTAssertEqual(disconnectedCount, 1)
        XCTAssertEqual(partial, "Bunny wants")
        XCTAssertEqual(final, "Bunny wants a lantern adventure")
        XCTAssertEqual(localLevel, 0.1, accuracy: 0.0001)
        XCTAssertEqual(remoteLevel, 0.4, accuracy: 0.0001)
        XCTAssertTrue(userSpeaking)
        XCTAssertEqual(completionID, "utterance-7")
        XCTAssertEqual(receivedError, "Bridge problem")
    }

    func testDefaultBridgeErrorMessageAndUnknownMessagesAreSafe() {
        let client = RealtimeVoiceClient()
        var receivedError = ""
        client.onError = { receivedError = $0 }

        client.handleBridgeMessageForTesting(["type": "error"])
        client.handleBridgeMessageForTesting(["type": "unknown_event", "value": 1])

        XCTAssertEqual(receivedError, "Realtime bridge error")
    }

    func testErrorDescriptions() {
        XCTAssertEqual(
            RealtimeVoiceClient.RealtimeError.notReady.errorDescription,
            "Realtime bridge is not ready yet."
        )
        XCTAssertEqual(
            RealtimeVoiceClient.RealtimeError.invalidBridgeResponse.errorDescription,
            "Realtime bridge returned an invalid response."
        )
        XCTAssertEqual(
            RealtimeVoiceClient.RealtimeError.bridgeReadyTimedOut.errorDescription,
            "Realtime bridge did not become ready in time."
        )
        XCTAssertEqual(
            RealtimeVoiceClient.RealtimeError.bridgeReadyFailed("Bridge setup failed").errorDescription,
            "Bridge setup failed"
        )
        XCTAssertEqual(
            RealtimeVoiceClient.RealtimeError.disconnectedBeforeReady.errorDescription,
            "Realtime bridge disconnected before it was ready."
        )
        XCTAssertEqual(
            RealtimeVoiceClient.RealtimeError.connectFailed("Socket failed").errorDescription,
            "Socket failed"
        )
    }
}
