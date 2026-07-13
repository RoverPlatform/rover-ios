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

private let gradientBaseColor = Color(
    uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? .systemGray5
            : .systemGray4
    }
)

struct GradientBackground<S: Shape>: View {
    let shape: S
    let size: CGFloat

    var body: some View {
        shape
            .fill(gradientBaseColor)
            .overlay { shape.fill(Color.accentColor.opacity(0.18)) }
            .overlay {
                shape.fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: 1,
                        endRadius: size * 1.2
                    )
                )
            }
    }
}
