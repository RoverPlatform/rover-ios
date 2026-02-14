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

import RoverData
import RoverFoundation
import SafariServices
import SwiftUI
import WebKit
import os.log

struct PostDetailView: View {

    @Environment(\.hubContainer) private var container
    @Environment(\.eventQueue) private var eventQueue
    @Environment(\.inboxSync) private var inboxSync
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @State private var post: Post?
    @State private var presentingURL: ModalLinkURL?
    @State private var isLoadingOverlay: Bool = false
    @State private var alertError: ContentAlertError?
    @Binding private var showAlert: Bool
    let postID: String?
    let accentColor: Color

    init(post: Post, accentColor: Color, showAlert: Binding<Bool>) {
        self.postID = post.id?.uuidString
        self._post = State(initialValue: post)
        self.accentColor = accentColor
        self._showAlert = showAlert
    }

    init(postID: String?, accentColor: Color, showAlert: Binding<Bool>) {
        self.postID = postID
        self.accentColor = accentColor
        self._showAlert = showAlert
    }

    var body: some View {
        ZStack {
            if let post = post {
                if let url = post.url, isURLSchemeAllowedForWebView(url) {
                    WebViewContainer(url: url, accentColor: accentColor) { url in
                        handleLinkTap(url: url)
                    }
                    .navigationTitle(post.subject ?? "Post")
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    // Post URL has an unsafe scheme - show error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Unable to display content")
                            .font(.headline)
                        Text("The content URL is invalid or uses an unsupported format.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .navigationTitle(post.subject ?? "Post")
                    .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                ProgressView()
            }
        }

        .overlay {
            if isLoadingOverlay {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert(isPresented: $showAlert) {
            // Note: We use a separate boolean flag for alert presentation instead of relying solely on
            // `.alert(item: $alertError)` because SwiftUI's `.alert(item:)` modifier doesn't properly
            // handle the transition from a non-nil value to `nil` while the alert is being displayed.
            // This causes alerts to not dismiss when a new postID is passed via NavigationDestination.
            // Using `.alert(isPresented: $showAlert)` with explicit control via `showError()` and
            // `hideError()` ensures proper alert dismissal behavior.
            Alert(
                title: Text(alertError?.title ?? "Error"),
                message: Text(alertError?.message ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK")) {
                    dismiss()
                }
            )
        }
        .sheet(
            item: $presentingURL,
            content: { link in
                ModalBrowser(url: link.url)
            }
        )
        .task(id: postID) {
            // Reset state when postID changes to ensure clean loading
            post = nil
            hideError()
            isLoadingOverlay = false

            await loadPost()
        }
    }

    private func loadPost() async {
        guard let postID = postID, !postID.isEmpty else {
            showError(.notFound(.post))
            return
        }

        guard let container = container else {
            showError(.error("Storage not available"))
            return
        }

        // Phase 1: Fast local lookup
        if let localPost = container.fetchPostByID(uuidString: postID) {
            post = localPost
            markPostAsRead()
            trackPostOpened()
            return
        }

        // Phase 2: Not found locally, trigger sync and retry
        isLoadingOverlay = true

        guard let inboxSync = inboxSync else {
            isLoadingOverlay = false
            showError(.error("Sync service unavailable"))
            return
        }

        // Trigger sync and wait for completion
        let syncSuccess = await inboxSync.sync()

        // Phase 3: Retry after sync
        isLoadingOverlay = false
        if syncSuccess, let syncedPost = container.fetchPostByID(uuidString: postID) {
            post = syncedPost
            markPostAsRead()
            trackPostOpened()
        } else {
            showError(.notFound(.post))
        }
    }

    private func handleLinkTap(url: URL) {
        let scheme = url.scheme?.lowercased()

        // Block dangerous URL schemes that could execute code or load arbitrary data
        guard isURLSchemeSafeForLinkTap(scheme) else {
            os_log(
                "Blocked link tap with unsafe URL scheme: %@",
                log: .hub,
                type: .info,
                scheme ?? "nil"
            )
            return
        }

        trackPostLinkClicked(url: url)

        if scheme == "http" || scheme == "https" {
            // Use ModalBrowser (SFSafariViewController) for HTTP/HTTPS URLs
            presentingURL = ModalLinkURL(url: url)
        } else {
            // Use system's URL opening for safe schemes (mailto:, tel:, sms:, etc.)
            UIApplication.shared.open(url)
        }
    }

    /// Checks if a URL is safe to load in the WebView (only http/https allowed)
    private func isURLSchemeAllowedForWebView(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// Checks if a URL scheme is safe for link taps.
    /// Blocks only code execution schemes (javascript:, vbscript:) and inline data schemes (data:, blob:).
    /// Allows deep links (myapp://), system schemes (tel:, mailto:, sms:), and standard URLs (http/https).
    private func isURLSchemeSafeForLinkTap(_ scheme: String?) -> Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        // Block schemes that could execute arbitrary code or embed untrusted inline content
        let blockedSchemes = ["javascript", "data", "blob", "vbscript"]
        return !blockedSchemes.contains(scheme)
    }

    private func markPostAsRead() {
        guard let container = container, let post = post else { return }
        container.markPostAsRead(post)
    }

    private func resolvedPostUUID() -> UUID? {
        if let post = post, let postID = post.id {
            return postID
        } else if let postIDString = postID, let postID = UUID(uuidString: postIDString) {
            return postID
        } else {
            return nil
        }
    }

    private func trackPostOpened() {
        guard let eventQueue = eventQueue else { return }
        guard let uuid = resolvedPostUUID() else { return }
        let event = EventInfo.postOpened(postID: uuid)
        eventQueue.addEvent(event)
    }

    private func trackPostLinkClicked(url: URL) {
        guard let eventQueue = eventQueue else { return }
        guard let uuid = resolvedPostUUID() else { return }
        let event = EventInfo.postLinkClicked(postID: uuid, link: url.absoluteString)
        eventQueue.addEvent(event)
    }

    private func showError(_ error: ContentAlertError) {
        alertError = error
        showAlert = true
    }

    private func hideError() {
        alertError = nil
        showAlert = false
    }
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL?
    let onLinkTap: (URL) -> Void
    let accentColor: Color

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    init(url: URL?, accentColor: Color, onLinkTap: @escaping (URL) -> Void) {
        self.url = url
        self.onLinkTap = onLinkTap
        self.accentColor = accentColor
        os_log("Presenting post URL: %{private}@", log: .hub, type: .debug, url?.absoluteString ?? "none")
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
        // Load URL if it has changed and scheme is safe (http/https only)
        if let url = url,
            context.coordinator.currentURL != url,
            isURLSchemeAllowed(url)
        {
            webView.load(URLRequest(url: url))
            context.coordinator.currentURL = url
        }

        // Update font size and accent color when dynamic type size or color scheme changes
        if context.coordinator.lastDynamicTypeSize != dynamicTypeSize
            || context.coordinator.lastColorScheme != colorScheme
        {

            updateWebViewStyles(webView)

            // Update tracking values
            context.coordinator.lastDynamicTypeSize = dynamicTypeSize
            context.coordinator.lastColorScheme = colorScheme
        }
    }

    private func updateWebViewStyles(_ webView: WKWebView) {
        let js = generateStylesJavaScript()

        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                os_log("Error updating web view styles: %@", log: .hub, type: .error, error.localizedDescription)
            }
        }
    }

    /// Generates the JavaScript needed to set CSS styles for accent color and font size
    private func generateStylesJavaScript() -> String {
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

        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let scheme = url.scheme?.lowercased()

            // Block dangerous URL schemes that could execute arbitrary code or load unsafe content
            let blockedSchemes = ["javascript", "data", "blob", "vbscript"]
            if let scheme = scheme, blockedSchemes.contains(scheme) {
                os_log(
                    "Blocked navigation to unsafe URL scheme: %@",
                    log: .hub,
                    type: .info,
                    scheme
                )
                decisionHandler(.cancel)
                return
            }

            // Intercept user-tapped links (excluding programmatic loads)
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)  // Cancel normal webview navigation

                // Trigger modal presentation through the parent SwiftUI view
                onLinkTap(url)
                return
            }

            // Allow http/https navigations for content loading (initial load, reloads, etc.)
            if scheme == "http" || scheme == "https" {
                decisionHandler(.allow)
            } else {
                // For non-link-activated navigations with other schemes (e.g., deep links via JS),
                // cancel but attempt to open externally
                decisionHandler(.cancel)
                onLinkTap(url)
            }
        }
    }

    /// Validates that the URL uses only http or https scheme to prevent loading unsafe content
    private func isURLSchemeAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
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
        @State private var container = InboxPersistentContainer(storage: .inMemory)
        @State private var samplePost: Post?
        @State private var showAlert: Bool = false

        var body: some View {
            NavigationView {
                if let post = samplePost {
                    PostDetailView(post: post, accentColor: Color.purple, showAlert: $showAlert)
                } else {
                    Text("Loading...")
                        .onAppear {
                            // Create a sample post for the preview
                            samplePost = container.createSamplePreviewPost()
                        }
                }
            }
            .environment(\.hubContainer, container)
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
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            // Successfully extracted RGB values (works for RGB, grayscale, and other color spaces)
        } else if let components = cgColor.components {
            // Fallback to cgColor.components extraction
            if components.count >= 3 {
                r = components[0]
                g = components[1]
                b = components[2]
                a = cgColor.alpha
            } else if components.count >= 1 {
                // Grayscale: use white value for all RGB channels
                r = components[0]
                g = components[0]
                b = components[0]
                a = cgColor.alpha
            }
            // If no components, r, g, b, a remain 0 (black)
        }
        // If both methods fail, defaults to black (r=0, g=0, b=0, a=0)

        let rf = Float(r)
        let gf = Float(g)
        let bf = Float(b)
        let af = Float(a)

        if af < 1.0 {
            return String(format: "color(srgb %.6f %.6f %.6f / %.6f)", rf, gf, bf, af)
        } else {
            return String(format: "color(srgb %.6f %.6f %.6f)", rf, gf, bf)
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
