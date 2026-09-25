import Foundation

/// Builds the standalone App Screens `onOpenExternalURL` handler.
///
/// Keyed on `isModal` (i.e. whether `ExperienceViewController.onDismissButtonPressed`
/// was supplied): a modal presentation is the navigation surface and must dismiss its
/// whole presentation before opening (the "owner" branch); an embedded experience is
/// content, so it registers NO owner handler (`nil`), which routes the open through
/// `AppScreensSheetCollapseCoordinator`'s open-in-place path instead.
///
/// `dismiss` is completion-capable so the `open` fires only after the presentation is
/// gone (mirrors `HubHostingController`'s dismiss-then-open); `open` is injected so the
/// URL-open + failure-logging side effect stays out of this pure factory (testability).
package func makeAppScreensOpenExternalURLHandler(
    isModal: Bool,
    dismiss: @escaping (_ completion: @escaping () -> Void) -> Void,
    open: @escaping (URL) -> Void
) -> ((URL, Bool) -> Void)? {
    guard isModal else {
        return nil
    }
    return { url, shouldDismiss in
        guard shouldDismiss else {
            open(url)
            return
        }
        dismiss { open(url) }
    }
}
