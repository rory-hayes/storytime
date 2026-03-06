import SwiftUI
import WebKit

struct RealtimeVoiceBridgeView: UIViewRepresentable {
    let client: RealtimeVoiceClient

    func makeUIView(context: Context) -> WKWebView {
        client.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
