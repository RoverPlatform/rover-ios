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
import SafariServices
import os.log
import RoverData
import RoverFoundation

struct PostDetailView: View {
    let post: Post

    @Environment(\.communicationHubContainer) private var container
    @Environment(\.eventQueue) private var eventQueue
    @State private var presentingURL: ModalLinkURL?

    var body: some View {
        WebViewContainer(url: post.url) { url in
            handleLinkTap(url)
        }
        .navigationTitle(post.subject ?? "Post")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            markPostAsRead()
            trackPostOpened()
        }
        .sheet(item: $presentingURL, content: { link in
            ModalBrowser(url: link.url)
        })
    }
    
    private func handleLinkTap(_ url: URL) {
        // Track link click event
        trackPostLinkClicked(url: url)
        
        // Check if the URL scheme is supported by SFSafariViewController
        let scheme = url.scheme?.lowercased()
        
        if scheme == "http" || scheme == "https" {
            // Use ModalBrowser (SFSafariViewController) for HTTP/HTTPS URLs
            presentingURL = ModalLinkURL(url: url)
        } else {
            // Use system's URL opening for other schemes (mailto:, tel:, custom schemes, etc.)
            UIApplication.shared.open(url)
        }
    }
    
    private func markPostAsRead() {
        guard let container = container else { return }
        container.markPostAsRead(post)
    }
    
    private func trackPostOpened() {
        guard let eventQueue = eventQueue, let postID = post.id else { return }
        let event = EventInfo.postOpened(postID: postID)
        eventQueue.addEvent(event)
    }
    
    private func trackPostLinkClicked(url: URL) {
        guard let eventQueue = eventQueue, let postID = post.id else { return }
        let event = EventInfo.postLinkClicked(postID: postID, link: url.absoluteString)
        eventQueue.addEvent(event)
    }
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL?
    let onLinkTap: (URL) -> Void

    @Environment(\.roverCommunicationHubAccentColor) var accentColor
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    init(url: URL?, onLinkTap: @escaping (URL) -> Void) {
        self.url = url
        self.onLinkTap = onLinkTap
        os_log("Presenting post URL: %@", log: .communicationHub, type: .debug, url?.absoluteString ?? "none")
    }
    
    func makeUIView(context: Self.Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Inject the accent color and font size as CSS variables using WKUserScript for initial load
        let js = generateStylesJavaScript()

        let userScript = WKUserScript(
            source: js,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(userScript)
        
        // Create the web view
        let webView = WKWebView(frame: .zero, configuration: configuration)
        // if #available(iOS 17.0, *) {
        //     webView.isInspectable = true
        // }
        webView.navigationDelegate = context.coordinator
        
        // Prevent white flash during initial load
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Self.Context) {
        // Load URL if it has changed
        if let url = url, context.coordinator.currentURL != url {
            webView.load(URLRequest(url: url))
            context.coordinator.currentURL = url
        }
        
        // Update font size and accent color when dynamic type size or color scheme changes
        if context.coordinator.lastDynamicTypeSize != dynamicTypeSize || 
           context.coordinator.lastColorScheme != colorScheme {
            
            updateWebViewStyles(webView)
            
            // Update tracking values
            context.coordinator.lastDynamicTypeSize = dynamicTypeSize
            context.coordinator.lastColorScheme = colorScheme
        }
    }
    
    private func updateWebViewStyles(_ webView: WKWebView) {
        let js = generateStylesJavaScript()
        
        webView.evaluateJavaScript(js) { (_, error) in
            if let error = error {
                print("Error updating web view styles: \(error)")
            }
        }
    }
    
    /// Generates the JavaScript needed to set CSS styles for accent color and font size
    private func generateStylesJavaScript(
    ) -> String {
        let accentUIColor = UIColor(accentColor)
        let colorString = accentUIColor.resolvedColor(with: colorScheme.asTraits).toCSSColorString()
        let fontSizeMultiplier = fontSizeMultiplierForDynamicTypeSize(dynamicTypeSize)
        
        return """
            document.documentElement.style.setProperty('--accent-color', '\(colorString)');
            document.documentElement.style.fontSize = '\(fontSizeMultiplier)rem';
            console.log('Dynamic type updated: \(dynamicTypeSize), fontSize: \(fontSizeMultiplier)rem');
        """
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, onLinkTap: onLinkTap)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer
        var currentURL: URL?
        var lastDynamicTypeSize: DynamicTypeSize?
        var lastColorScheme: ColorScheme?
        let onLinkTap: (URL) -> Void
        
        init(_ parent: WebViewContainer, onLinkTap: @escaping (URL) -> Void) {
            self.parent = parent
            self.onLinkTap = onLinkTap
            self.lastDynamicTypeSize = parent.dynamicTypeSize
            self.lastColorScheme = parent.colorScheme
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Apply styles once the page is loaded
            parent.updateWebViewStyles(webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Intercept user-tapped links (excluding programmatic loads)
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {

                decisionHandler(.cancel) // Cancel normal webview navigation

                // Trigger modal presentation through the parent SwiftUI view
                onLinkTap(url)
                return
            }

            // Allow all other navigations (initial load, reloads, etc.)
            decisionHandler(.allow)
        }
    }

    // Helper method to convert DynamicTypeSize to a reasonable web font size multiplier
    private func fontSizeMultiplierForDynamicTypeSize(_ dynamicTypeSize: DynamicTypeSize) -> Float {
        switch dynamicTypeSize {
        case .xSmall:
            return 0.7
        case .small:
            return 0.8
        case .medium:
            return 0.9
        case .large:
            return 1.0
        case .xLarge:
            return 1.1
        case .xxLarge:
            return 1.2
        case .xxxLarge:
            return 1.3
        case .accessibility1:
            return 1.5
        case .accessibility2:
            return 1.7
        case .accessibility3:
            return 1.9
        case .accessibility4:
            return 2.1
        case .accessibility5:
            return 2.3
        @unknown default:
            return 1.0
        }
    }
}

private struct ModalLinkURL: Identifiable {
    var url: URL

    var id: String {
        url.absoluteString
    }
}

#if DEBUG
struct PostDetailPreviewContent: View {
    @State private var container = RCHPersistentContainer(storage: .inMemory)
    @State private var samplePost: Post?
    
    var body: some View {
        NavigationView {
            if let post = samplePost {
                PostDetailView(post: post)
                    .environment(\.roverCommunicationHubAccentColor, Color.purple)
            } else {
                Text("Loading...")
                    .onAppear {
                        // Create a sample post for the preview
                        samplePost = container.createSamplePreviewPost()
                    }
            }
        }
        .environment(\.communicationHubContainer, container)
    }
}

#Preview("Dark Mode") {
    PostDetailPreviewContent()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    PostDetailPreviewContent()
        .preferredColorScheme(.light)

}
#endif

private struct ModalBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Self.Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Self.Context) {
        // no-op, navigating to new URL not supported
    }
}


private extension UIColor {
    /// Convert a UIColor to a CSS color(srgb ...) expression
    func toCSSColorString() -> String {
        guard let components = cgColor.components, components.count >= 3 else {
            return "color(srgb 0 0 0)" // Default to black if components can't be retrieved
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = Float(cgColor.alpha)
        
        if a < 1.0 {
            return String(format: "color(srgb %.6f %.6f %.6f / %.6f)", r, g, b, a)
        } else {
            return String(format: "color(srgb %.6f %.6f %.6f)", r, g, b)
        }
    }
}

extension ColorScheme {
    var asTraits: UITraitCollection {
        switch self {
        case .light:
            return UITraitCollection(userInterfaceStyle: .light)
        case .dark:
            return UITraitCollection(userInterfaceStyle: .dark)
        @unknown default:
            return UITraitCollection(userInterfaceStyle: .light)
        }
    }
}
