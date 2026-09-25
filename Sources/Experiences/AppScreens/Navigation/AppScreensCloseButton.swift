import SwiftUI

/// The App Screen close (X) affordance, shared by the root standalone host and the
/// sheet host. Mirrors the Hub's `CompatibleInboxToolbarButton` chrome via the shared
/// `toolbarItemsRequireCompatibilityChrome` gate so both bars share one design
/// language: a `.thinMaterial` circle behind the glyph in compatibility mode
/// (pre-iOS-26, or an app that opts out of the iOS 26 redesign via
/// `UIDesignRequiresCompatibility`), and a plain glyph the iOS 26 navigation bar
/// draws as liquid glass otherwise. `tint`/`foregroundStyle(.primary)` keep it from
/// inheriting a surrounding accent color.
package struct AppScreensCloseButton: View {
    let action: () -> Void

    package init(action: @escaping () -> Void) {
        self.action = action
    }

    package var body: some View {
        // SwiftUI types are fully qualified: `Image`, `ZStack` (and `Text`) are
        // shadowed in this module by the Experiences layer nodes of the same name
        // (Model/Nodes/), so a bare `Image`/`ZStack` resolves to the node class.
        SwiftUI.Button(action: action) {
            if toolbarItemsRequireCompatibilityChrome {
                SwiftUI.ZStack {
                    SwiftUI.Circle()
                        .fill(.thinMaterial)
                        .shadow(radius: 5)
                        .frame(width: 40, height: 40)
                    SwiftUI.Image(systemName: "xmark")
                }
            } else {
                SwiftUI.Image(systemName: "xmark")
            }
        }
        .tint(.primary)
        .foregroundStyle(.primary)
        .accessibilityLabel(
            // Plain `String` overload, not the `Text` one: `Text` is shadowed in this
            // module by the Experiences `Text` node (Model/Nodes/Text.swift).
            NSLocalizedString(
                "Close",
                comment: "Rover App Screen close button accessibility label"
            )
        )
        .accessibilityIdentifier("rover.appscreen.sheet.close")
    }
}
