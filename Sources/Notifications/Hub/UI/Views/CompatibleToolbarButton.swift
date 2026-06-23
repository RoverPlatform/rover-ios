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

// Evaluated once per process — both conditions (plist key and OS version) are immutable after launch.
private let toolbarButtonRequiresCompatibilityBackground: Bool = {
    let requiresCompatibility =
        Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool ?? false
    if requiresCompatibility { return true }
    if #available(iOS 26, *) { return false }
    return true
}()

struct CompatibleToolbarButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            if toolbarButtonRequiresCompatibilityBackground {
                ZStack {
                    Circle()
                        .fill(.thinMaterial)
                        .shadow(radius: 5)
                        .frame(width: 40, height: 40)
                    label()
                }
            } else {
                label()
            }
        }
        .tint(.primary)
        .foregroundStyle(.primary)
    }
}
