import SwiftUI

/// The standalone (non-Hub) SwiftUI host for a V3 App Screens experience, embedded by
/// `ExperienceViewController` via a `UIHostingController`. Owns the `NavigationStack`
/// and its `NavigationPath` (the stack is stable for the presentation's lifetime, so
/// `@State` persists), and forwards the
/// owner handlers into `AppScreensHostView`.
///
/// `onClose != nil` ⇒ modal: a root-only close (X) is shown and the owner branch's
/// dismiss-then-open handler is active. `onClose == nil` ⇒ embedded: clean bar, no
/// owner handler (the coordinator opens in place).
struct AppScreensNavigationHostView: View {
    let url: URL
    let onClose: (() -> Void)?
    let onOpenExternalURL: ((URL, Bool) -> Void)?

    @State private var path = NavigationPath()

    var body: some View {
        SwiftUI.NavigationStack(path: $path) {
            AppScreensHostView(
                url: url,
                path: $path,
                onDismiss: onClose,
                onOpenURL: nil,
                onOpenExternalURL: onOpenExternalURL
            )
            .id(url)
            // The hosted screen `.ignoresSafeArea()`, which would otherwise collapse
            // the bar; force it visible so the root close item has a bar to sit in
            // (same reason HubContentView / the sheet host force it).
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                if onClose != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        AppScreensCloseButton { onClose?() }
                    }
                }
            }
            // Defeats a host-app global `UINavigationBar.appearance()` proxy, which
            // SwiftUI modifiers alone cannot override (mirrors HubContentView).
            .resetNavBarAppearance()
        }
    }
}
