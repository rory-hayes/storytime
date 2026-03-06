import XCTest
@testable import StoryTime

@MainActor
final class RealtimeVoiceClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.storytime.session-token")
        defaults.removeObject(forKey: "com.storytime.session-expiry")
    }

    func testSpeakCancelAndDisconnectSendCommandsOnceBridgeIsReady() async {
        let client = RealtimeVoiceClient()
        var commands: [(String, [String: Any])] = []
        client.bridgeCommandSender = { command, payload in
            commands.append((command, payload))
        }
        client.setBridgeReadyForTesting()

        await client.speak(text: "Hello there")
        await client.cancelAssistantSpeech()
        await client.disconnect()

        XCTAssertEqual(commands.map(\.0), ["speak", "cancel", "disconnect"])
        XCTAssertEqual(commands.first?.1["text"] as? String, "Hello there")
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
        client.handleBridgeMessageForTesting(["type": "connected"])
        try await connectTask.value

        XCTAssertEqual(sentCommand, "connect")
        XCTAssertEqual(sentPayload["ticket"] as? String, "signed-ticket")
        XCTAssertEqual(sentPayload["installId"] as? String, "install-123")
        XCTAssertEqual(sentPayload["sessionToken"] as? String, "session-token-123")
        XCTAssertEqual(sentPayload["callURL"] as? String, "https://backend.example.com/v1/realtime/call")
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
        client.handleBridgeMessageForTesting(["type": "bridge_ready"])
        await Task.yield()
        client.handleBridgeMessageForTesting(["type": "disconnected"])
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
        var completionCount = 0
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
        client.onAssistantResponseCompleted = { completionCount += 1 }
        client.onError = { receivedError = $0 }

        client.handleBridgeMessageForTesting(["type": "connected"])
        client.handleBridgeMessageForTesting(["type": "levels", "localLevel": 0.1, "remoteLevel": 0.4])
        client.handleBridgeMessageForTesting(["type": "user_speech_state", "speaking": true])
        client.handleBridgeMessageForTesting(["type": "transcript_partial", "text": "Bunny wants"])
        client.handleBridgeMessageForTesting(["type": "transcript_final", "text": "Bunny wants a lantern adventure"])
        client.handleBridgeMessageForTesting(["type": "assistant_response_completed"])
        client.handleBridgeMessageForTesting(["type": "error", "message": "Bridge problem"])
        client.handleBridgeMessageForTesting(["type": "disconnected"])

        XCTAssertEqual(connectedCount, 1)
        XCTAssertEqual(disconnectedCount, 1)
        XCTAssertEqual(partial, "Bunny wants")
        XCTAssertEqual(final, "Bunny wants a lantern adventure")
        XCTAssertEqual(localLevel, 0.1, accuracy: 0.0001)
        XCTAssertEqual(remoteLevel, 0.4, accuracy: 0.0001)
        XCTAssertTrue(userSpeaking)
        XCTAssertEqual(completionCount, 1)
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
    }
}
