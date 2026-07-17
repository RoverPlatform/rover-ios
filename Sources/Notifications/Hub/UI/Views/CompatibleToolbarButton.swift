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

import RoverExperiences
import SwiftUI

struct CompatibleInboxToolbarButton: View {
    let badge: String?
    let action: () -> Void

    var body: some View {
        // The iOS 26 navigation bar renders SwiftUI's `.badge` on the toolbar item
        // itself. In compatibility mode — a pre-iOS-26 OS, or an app that opts out of
        // the iOS 26 redesign via `UIDesignRequiresCompatibility` — the button is drawn
        // as a plain circular background where `.badge` renders nothing, so the count
        // has to be drawn manually. Split into two variants so each path is explicit.
        Group {
            if toolbarItemsRequireCompatibilityChrome {
                CompatibilityInboxToolbarButton(badge: badge, action: action)
            } else {
                NativeInboxToolbarButton(badge: badge, action: action)
            }
        }
        .tint(.primary)
        .foregroundStyle(.primary)
        .accessibilityLabel(
            Text(
                NSLocalizedString(
                    "Inbox",
                    comment: "Rover Hub inbox button accessibility label"
                )
            )
        )
        .accessibilityIdentifier("rover.hub.inbox")
    }
}

/// iOS 26 navigation-bar variant. The system decorates the toolbar item with a native
/// badge via the `.badge` modifier.
private struct NativeInboxToolbarButton: View {
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "envelope")
                .badge(badge)
        }
        // SwiftUI's toolbar preference system does not reliably propagate badge
        // value updates to the navigation bar. Assigning a new identity via .id()
        // each time the badge changes forces SwiftUI to recreate the view, which
        // re-sends the toolbar preference and causes the navigation bar to update.
        .id(badge)
    }
}

/// iOS 17/18 (and `UIDesignRequiresCompatibility`) variant. `.badge` renders nothing
/// on the plain compatibility button, so the count is drawn manually as a corner badge,
/// centered on the envelope's top-trailing corner.
private struct CompatibilityInboxToolbarButton: View {
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .shadow(radius: 5)
                    .frame(width: 40, height: 40)
                Image(systemName: "envelope")
            }
            .overlay(alignment: .topTrailing) {
                if let badge {
                    BadgeLabel(text: badge)
                        .alignmentGuide(.top) { dimensions in dimensions[VerticalAlignment.center] }
                        .alignmentGuide(.trailing) { dimensions in dimensions[HorizontalAlignment.center] }
                }
            }
        }
        .id(badge)
    }
}

/// A red pill mirroring the system unread badge, drawn manually for the compatibility
/// toolbar where SwiftUI's `.badge` modifier does not render.
private struct BadgeLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(.red))
    }
}
