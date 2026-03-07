import Foundation
import WebKit

@MainActor
protocol RealtimeVoiceControlling: AnyObject {
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: (() -> Void)? { get set }
    var onTranscriptPartial: ((String) -> Void)? { get set }
    var onTranscriptFinal: ((String) -> Void)? { get set }
    var onLevels: ((CGFloat, CGFloat) -> Void)? { get set }
    var onUserSpeechChanged: ((Bool) -> Void)? { get set }
    var onAssistantResponseCompleted: ((String?) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }

    func connect(baseURL: URL, endpointPath: String, session: RealtimeSessionData, installId: String) async throws
    func speak(text: String, utteranceId: String?) async
    func cancelAssistantSpeech() async
    func disconnect() async
}

@MainActor
final class RealtimeVoiceClient: NSObject, ObservableObject, RealtimeVoiceControlling {
    enum RealtimeError: LocalizedError, Equatable {
        case notReady
        case invalidBridgeResponse
        case bridgeReadyTimedOut
        case bridgeReadyFailed(String)
        case disconnectedBeforeReady
        case connectFailed(String)

        var errorDescription: String? {
            switch self {
            case .notReady:
                return "Realtime bridge is not ready yet."
            case .invalidBridgeResponse:
                return "Realtime bridge returned an invalid response."
            case .bridgeReadyTimedOut:
                return "Realtime bridge did not become ready in time."
            case .bridgeReadyFailed(let message):
                return message
            case .disconnectedBeforeReady:
                return "Realtime bridge disconnected before it was ready."
            case .connectFailed(let message):
                return message
            }
        }
    }

    let webView: WKWebView

    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onTranscriptPartial: ((String) -> Void)?
    var onTranscriptFinal: ((String) -> Void)?
    var onLevels: ((CGFloat, CGFloat) -> Void)?
    var onUserSpeechChanged: ((Bool) -> Void)?
    var onAssistantResponseCompleted: ((String?) -> Void)?
    var onError: ((String) -> Void)?

    private static let embeddedBridgeOriginURL = URL(string: "https://localhost/")!
    private let bridgeHandlerName = "storytimeRealtime"
    private var bridgeReady = false
    private var bridgeReadyFailure: RealtimeError?
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var messageProxy: WeakScriptMessageHandler?
    var bridgeReadyTimeoutNanoseconds: UInt64 = 5_000_000_000
    var bridgeCommandSender: ((String, [String: Any]) async throws -> Void)?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let userContentController = WKUserContentController()
        configuration.userContentController = userContentController
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        let proxy = WeakScriptMessageHandler(delegate: self)
        self.messageProxy = proxy
        webView.configuration.userContentController.add(proxy, name: bridgeHandlerName)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        loadBridge()
    }

    func connect(baseURL: URL, endpointPath: String, session: RealtimeSessionData, installId: String) async throws {
        if bridgeReadyFailure != nil && !bridgeReady {
            loadBridge()
        }
        try await waitForBridgeReady()
        let callURL = resolveCallURL(baseURL: baseURL, endpointPath: endpointPath)

        let payload: [String: Any] = [
            "callURL": callURL,
            "ticket": session.ticket,
            "installId": installId,
            "sessionToken": AppSession.currentToken ?? ""
        ]

        try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
            guard let self else {
                continuation.resume(throwing: RealtimeError.notReady)
                return
            }

            self.connectionContinuation = continuation
            Task {
                do {
                    try await self.send(command: "connect", payload: payload)
                } catch {
                    self.connectionContinuation = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func speak(text: String, utteranceId: String? = nil) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var payload: [String: Any] = ["text": text]
        if let utteranceId {
            payload["utteranceId"] = utteranceId
        }
        try? await send(command: "speak", payload: payload)
    }

    func cancelAssistantSpeech() async {
        try? await send(command: "cancel", payload: [:])
    }

    func disconnect() async {
        try? await send(command: "disconnect", payload: [:])
    }

    private func loadBridge() {
        bridgeReady = false
        bridgeReadyFailure = nil
        connectionContinuation = nil
        // The bridge HTML is embedded locally. It only needs a secure origin for
        // getUserMedia/WebRTC; the actual realtime call target comes from payload.callURL.
        webView.loadHTMLString(Self.bridgeHTML, baseURL: Self.embeddedBridgeOriginURL)
    }

    private func waitForBridgeReady() async throws {
        guard !bridgeReady else { return }

        let deadline = Date().addingTimeInterval(Double(bridgeReadyTimeoutNanoseconds) / 1_000_000_000)
        while !bridgeReady {
            if let bridgeReadyFailure {
                throw bridgeReadyFailure
            }

            if Date() >= deadline {
                throw RealtimeError.bridgeReadyTimedOut
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func send(command: String, payload: [String: Any]) async throws {
        guard bridgeReady else {
            throw RealtimeError.notReady
        }

        if let bridgeCommandSender {
            try await bridgeCommandSender(command, payload)
            return
        }

        _ = try await webView.callAsyncJavaScript(
            "window.StoryTimeRealtime.receiveCommand(command, payload)",
            arguments: [
                "command": command,
                "payload": payload
            ],
            in: nil,
            contentWorld: .page
        )
    }

    private func resolveCallURL(baseURL: URL, endpointPath: String) -> String {
        let trimmedPath = endpointPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if let absolute = URL(string: trimmedPath), absolute.scheme != nil {
            return absolute.absoluteString
        }

        if let resolved = URL(string: trimmedPath, relativeTo: baseURL)?.absoluteURL {
            return resolved.absoluteString
        }

        return baseURL.appending(path: trimmedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).absoluteString
    }

    private func handleBridgeMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "bridge_ready":
            bridgeReady = true
            bridgeReadyFailure = nil

        case "connected":
            connectionContinuation?.resume(returning: ())
            connectionContinuation = nil
            onConnected?()

        case "disconnected":
            if connectionContinuation != nil {
                connectionContinuation?.resume(throwing: RealtimeError.invalidBridgeResponse)
                connectionContinuation = nil
            } else if !bridgeReady {
                bridgeReadyFailure = .disconnectedBeforeReady
            }
            onDisconnected?()

        case "levels":
            let local = CGFloat((message["localLevel"] as? NSNumber)?.doubleValue ?? 0)
            let remote = CGFloat((message["remoteLevel"] as? NSNumber)?.doubleValue ?? 0)
            onLevels?(local, remote)

        case "user_speech_state":
            let speaking = message["speaking"] as? Bool ?? false
            onUserSpeechChanged?(speaking)

        case "transcript_partial":
            if let text = message["text"] as? String {
                onTranscriptPartial?(text)
            }

        case "transcript_final":
            if let text = message["text"] as? String {
                onTranscriptFinal?(text)
            }

        case "assistant_response_completed":
            onAssistantResponseCompleted?(message["utteranceId"] as? String)

        case "error":
            let errorMessage = message["message"] as? String ?? "Realtime bridge error"
            if connectionContinuation != nil {
                connectionContinuation?.resume(throwing: RealtimeError.connectFailed(errorMessage))
                connectionContinuation = nil
            } else if !bridgeReady {
                bridgeReadyFailure = .bridgeReadyFailed(errorMessage)
            }
            onError?(errorMessage)

        default:
            break
        }
    }

    private func failBridgeReadiness(_ failure: RealtimeError) {
        guard !bridgeReady else { return }

        bridgeReadyFailure = failure
        if let connectionContinuation {
            self.connectionContinuation = nil
            connectionContinuation.resume(throwing: failure)
        }
        onError?(failure.localizedDescription)
    }
}

extension RealtimeVoiceClient {
    func setBridgeReadyForTesting(_ ready: Bool = true) {
        bridgeReady = ready
        if ready {
            bridgeReadyFailure = nil
        }
    }

    func handleBridgeMessageForTesting(_ message: [String: Any]) {
        handleBridgeMessage(message)
    }
}

extension RealtimeVoiceClient: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let payload = message.body as? [String: Any] else { return }
        handleBridgeMessage(payload)
    }
}

extension RealtimeVoiceClient: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failBridgeReadiness(.bridgeReadyFailed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failBridgeReadiness(.bridgeReadyFailed(error.localizedDescription))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failBridgeReadiness(.bridgeReadyFailed("Realtime bridge stopped before it became ready."))
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.grant)
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

private extension RealtimeVoiceClient {
    static let bridgeHTML = """
    <!doctype html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
      <style>
        html, body {
          margin: 0;
          padding: 0;
          background: transparent;
        }
      </style>
    </head>
    <body>
      <script>
        (() => {
          const post = (payload) => {
            try {
              window.webkit.messageHandlers.storytimeRealtime.postMessage(payload);
            } catch (error) {
              console.error("postMessage failed", error);
            }
          };

          const sampleLevel = (analyser) => {
            if (!analyser) return 0;
            const data = new Uint8Array(analyser.fftSize);
            analyser.getByteTimeDomainData(data);
            let sum = 0;
            for (let i = 0; i < data.length; i += 1) {
              const normalized = (data[i] - 128) / 128;
              sum += normalized * normalized;
            }
            const rms = Math.sqrt(sum / data.length);
            return Math.max(0, Math.min(1, rms * 4.8));
          };

          const StoryTimeRealtime = {
            pc: null,
            dc: null,
            audio: null,
            audioContext: null,
            localAnalyser: null,
            remoteAnalyser: null,
            levelTimer: null,
            partialTranscript: "",
            userSpeaking: false,
            pendingUtteranceIds: [],
            responseUtteranceMap: new Map(),

            async receiveCommand(command, payload) {
              switch (command) {
                case "connect":
                  await this.connect(payload);
                  break;
                case "speak":
                  await this.speak(payload);
                  break;
                case "cancel":
                  this.cancel();
                  break;
                case "disconnect":
                  this.disconnect();
                  break;
                default:
                  break;
              }
            },

            async connect(payload) {
              try {
                await this.disconnect();

                this.audio = document.createElement("audio");
                this.audio.autoplay = true;
                this.audio.playsInline = true;

                const stream = await navigator.mediaDevices.getUserMedia({
                  audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                  }
                });

                const AudioCtx = window.AudioContext || window.webkitAudioContext;
                this.audioContext = this.audioContext || new AudioCtx();
                if (this.audioContext.state === "suspended") {
                  await this.audioContext.resume();
                }

                this.localAnalyser = this.createAnalyser(stream);

                this.pc = new RTCPeerConnection();
                stream.getTracks().forEach((track) => this.pc.addTrack(track, stream));

                this.pc.ontrack = async (event) => {
                  const remoteStream = event.streams[0];
                  this.audio.srcObject = remoteStream;
                  this.remoteAnalyser = this.createAnalyser(remoteStream);
                  try {
                    await this.audio.play();
                  } catch (error) {
                    post({ type: "error", message: `Audio playback failed: ${error.message}` });
                  }
                };

                this.pc.onconnectionstatechange = () => {
                  const state = this.pc?.connectionState || "unknown";
                  if (state === "connected") {
                    post({ type: "connected" });
                  }
                  if (state === "disconnected" || state === "failed" || state === "closed") {
                    post({ type: "disconnected" });
                  }
                };

                this.dc = this.pc.createDataChannel("oai-events");
                this.dc.onmessage = (event) => {
                  try {
                    this.handleRealtimeEvent(JSON.parse(event.data));
                  } catch (error) {
                    post({ type: "error", message: `Realtime event parse failed: ${error.message}` });
                  }
                };
                this.dc.onerror = (event) => {
                  post({ type: "error", message: "Realtime data channel error." });
                };

                const offer = await this.pc.createOffer({ offerToReceiveAudio: true });
                await this.pc.setLocalDescription(offer);

                const response = await fetch(payload.callURL, {
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json",
                    "x-storytime-install-id": payload.installId,
                    ...(payload.sessionToken ? { "x-storytime-session": payload.sessionToken } : {})
                  },
                  body: JSON.stringify({
                    ticket: payload.ticket,
                    sdp: offer.sdp
                  })
                });

                if (!response.ok) {
                  throw new Error(await response.text());
                }

                const call = await response.json();
                await this.pc.setRemoteDescription({
                  type: "answer",
                  sdp: call.answer_sdp
                });

                this.startLevelLoop();
              } catch (error) {
                post({ type: "error", message: error.message || "Realtime connection failed." });
              }
            },

            async speak(payload) {
              if (!this.dc || this.dc.readyState !== "open") {
                post({ type: "error", message: "Realtime session is not connected." });
                return;
              }

              const text = (payload?.text || "").trim();
              if (!text) return;
              this.pendingUtteranceIds.push(typeof payload?.utteranceId === "string" ? payload.utteranceId : null);

              this.dc.send(JSON.stringify({
                type: "response.create",
                response: {
                  modalities: ["audio"],
                  instructions: `Read the following to the child exactly as written. Do not add or change words.\\n\\n${text}`
                }
              }));
            },

            cancel() {
              if (this.dc && this.dc.readyState === "open") {
                this.dc.send(JSON.stringify({ type: "response.cancel" }));
              }
            },

            async disconnect() {
              if (this.levelTimer) {
                clearInterval(this.levelTimer);
                this.levelTimer = null;
              }

              if (this.dc) {
                this.dc.close();
                this.dc = null;
              }

              if (this.pc) {
                this.pc.getSenders().forEach((sender) => sender.track && sender.track.stop());
                this.pc.close();
                this.pc = null;
              }

              if (this.audio) {
                this.audio.pause();
                this.audio.srcObject = null;
                this.audio = null;
              }

              this.localAnalyser = null;
              this.remoteAnalyser = null;
              this.partialTranscript = "";
              this.userSpeaking = false;
              this.pendingUtteranceIds = [];
              this.responseUtteranceMap.clear();
            },

            handleRealtimeEvent(event) {
              switch (event.type) {
                case "response.created": {
                  const responseId = event.response?.id;
                  const utteranceId = this.pendingUtteranceIds.length > 0
                    ? this.pendingUtteranceIds.shift()
                    : null;
                  if (responseId) {
                    this.responseUtteranceMap.set(responseId, utteranceId ?? null);
                  }
                  break;
                }
                case "conversation.item.input_audio_transcription.delta":
                  this.partialTranscript = `${this.partialTranscript}${event.delta || ""}`;
                  post({ type: "transcript_partial", text: this.partialTranscript });
                  break;
                case "conversation.item.input_audio_transcription.completed":
                  this.partialTranscript = "";
                  if (event.transcript && event.transcript.trim()) {
                    post({ type: "transcript_final", text: event.transcript.trim() });
                  }
                  break;
                case "response.done": {
                  const responseId = event.response?.id;
                  let utteranceId = null;
                  if (responseId && this.responseUtteranceMap.has(responseId)) {
                    utteranceId = this.responseUtteranceMap.get(responseId) ?? null;
                    this.responseUtteranceMap.delete(responseId);
                  } else if (this.pendingUtteranceIds.length > 0) {
                    utteranceId = this.pendingUtteranceIds.shift();
                  }
                  post({ type: "assistant_response_completed", utteranceId });
                  break;
                }
                case "error":
                  post({ type: "error", message: event.error?.message || "Realtime API error." });
                  break;
                default:
                  break;
              }
            },

            createAnalyser(stream) {
              const source = this.audioContext.createMediaStreamSource(stream);
              const analyser = this.audioContext.createAnalyser();
              analyser.fftSize = 256;
              source.connect(analyser);
              return analyser;
            },

            startLevelLoop() {
              if (this.levelTimer) {
                clearInterval(this.levelTimer);
              }

              this.levelTimer = setInterval(() => {
                const localLevel = sampleLevel(this.localAnalyser);
                const remoteLevel = sampleLevel(this.remoteAnalyser);
                const speaking = localLevel > 0.06;

                if (speaking !== this.userSpeaking) {
                  this.userSpeaking = speaking;
                  post({ type: "user_speech_state", speaking });
                }

                post({
                  type: "levels",
                  localLevel,
                  remoteLevel
                });
              }, 60);
            }
          };

          window.StoryTimeRealtime = StoryTimeRealtime;
          post({ type: "bridge_ready" });
        })();
      </script>
    </body>
    </html>
    """
}
