// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import SwiftUI
import WebKit

struct WebViewView: View {
    @Environment(\.data) private var data
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    @Environment(\.deviceContext) private var deviceContext
    
    var webView: WebView
    
    @State private var loadErrorMessage: String?

    var body: some View {
        if let source = source {
            if let message = loadErrorMessage {
                webViewUI(source: source).loadError(message: message)
            } else {
                webViewUI(source: source)
            }
        }
    }
    
    private var source: WebView.Source? {
        switch webView.source {
        case .url(let value):
            let maybeValue = value.evaluatingExpressions(
                data: data,
                urlParameters: urlParameters,
                userInfo: userInfo,
                deviceContext: deviceContext
            )
                
            guard let value = maybeValue else {
                return nil
            }
            
            return .url(value)
        case .html(let value):
            let maybeValue = value.evaluatingExpressions(
                data: data,
                urlParameters: urlParameters,
                userInfo: userInfo,
                deviceContext: deviceContext
            )
                
            guard let value = maybeValue else {
                return nil
            }
            
            return .html(value)
        }
    }
    
    private func webViewUI(source: WebView.Source) -> WebViewUI {
        WebViewUI(
            source: source,
            isScrollEnabled: webView.isScrollEnabled,
            isUserInteractionEnabled: isEnabled,
            onFinish: { self.loadErrorMessage = nil },
            onFailure: { self.loadErrorMessage = $0.localizedDescription }
        )
    }
}

// MARK: WebViewUI


private struct WebViewUI: UIViewRepresentable {
    var source: WebView.Source
    var isScrollEnabled: Bool
    var isUserInteractionEnabled: Bool

    var onStart: (() -> Void)? = nil
    var onFinish: (() -> Void)? = nil
    var onFailure: ((Error) -> Void)? = nil

    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_4_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1"

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView  {
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = false
        preferences.isFraudulentWebsiteWarningEnabled = false

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = false
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.dataDetectorTypes = [.calendarEvent, .address, .phoneNumber]

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = Self.userAgent
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.scrollView.isScrollEnabled = isScrollEnabled

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = webView.backgroundColor

        webView.isUserInteractionEnabled = isUserInteractionEnabled
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {

        // This method is called multiple times, but we only care
        // about whether URL changed. In that case, trigger loading new URL
        // by WebView

        guard context.coordinator.source != source else {
            return
        }

        switch source {
        case .url(let value):
            if let embeddedVideoHTML = handleEmbeddedVideo(value) {
                webView.loadHTMLString(embeddedVideoHTML, baseURL: URL(string: "https://localhost")!)
            } else {
                let url = URL(string: value) ?? URL(string: "about:blank")!
                webView.load(URLRequest(url: url))
            }
        case .html(let value):
            webView.loadHTMLString(value, baseURL: nil)
        }
        
        context.coordinator.source = source
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
    }

    class Coordinator : NSObject, WKNavigationDelegate {
        var parent: WebViewUI
        var source: WebView.Source?

        init(_ webView: WebViewUI) {
            self.parent = webView
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            parent.onFinish?()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            parent.onStart?()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
            parent.onFailure?(error)
        }
    }

    private func handleEmbeddedVideo(_ urlString: String) -> String? {
        // Ensure we have a URL
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return nil
        }

        func hostMatches(_ host: String, domain: String) -> Bool {
            let lowercasedHost = host.lowercased()
            let lowercasedDomain = domain.lowercased()

            // Exact match
            if lowercasedHost == lowercasedDomain {
                return true
            }

            // Check if host ends with ".{domain}"
            let suffix = ".\(lowercasedDomain)"
            if lowercasedHost.hasSuffix(suffix) {
                // Ensure there's at least one character before the suffix
                // and the host doesn't start with a dot
                let prefixLength = lowercasedHost.count - suffix.count
                return prefixLength > 0 && !lowercasedHost.hasPrefix(".")
            }

            return false
        }

        let isYouTubeHost = hostMatches(host, domain: "youtube.com")
        let isYouTubeNoCookieHost = hostMatches(host, domain: "youtube-nocookie.com")
        let isYouTubeEmbed = isYouTubeHost && url.pathComponents.contains("embed")
        let isYouTubeNoCookie = isYouTubeNoCookieHost && url.pathComponents.contains("embed")

        let isVimeoEmbed = hostMatches(host, domain: "player.vimeo.com")

        guard isYouTubeEmbed || isYouTubeNoCookie || isVimeoEmbed else {
            return nil
        }

        // HTML-escape the URL for safe interpolation into HTML attribute
        // Validate URL scheme before using it
        guard let scheme = url.scheme, (scheme == "http" || scheme == "https") else {
            return nil
        }
        
        // HTML-escape the URL for safe interpolation into HTML attribute
        let escapedURL = url.absoluteString.htmlEscaped

        let html = """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no">
            <meta name="referrer" content="origin">
            <style>
              html, body {
                margin: 0;
                padding: 0;
                background: transparent;
                height: 100%;
                overflow: hidden;
              }
              iframe {
                border: 0;
                width: 100%;
                height: 100%;
              }
            </style>
          </head>
          <body>
            <iframe
              src="\(escapedURL)"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              referrerpolicy="strict-origin-when-cross-origin"
              allowfullscreen>
            </iframe>
          </body>
        </html>
        """

        return html
    }
}

// MARK: Modifiers

extension String {
    /// HTML-escapes special characters in a string for safe use in HTML attribute values.
    fileprivate var htmlEscaped: String {
        var result = self
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }
}


private extension WebViewUI {
    func loadError(message: String) -> some View {
        modifier(LoadErrorModifier(message: message))
    }
}


private struct LoadErrorModifier: ViewModifier {
    var message: String

    func body(content: Content) -> some View {
        SwiftUI.ZStack {
            content
            SwiftUI.HStack {
                SwiftUI.Image(systemName: "nosign")
                    .foregroundColor(Color(.systemRed))
                SwiftUI.Text(message)
                    .foregroundColor(Color(.secondaryLabel))
            }.padding()
        }
    }
}
