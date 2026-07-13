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

struct LogoView: View {
    let url: URL?
    let size: CGFloat

    init(
        url: URL?,
        size: CGFloat = 44,
    ) {
        self.url = url
        self.size = size
    }

    var body: some View {
        RemoteImageView(url: url, size: size, shape: shape) {
            fallbackView
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * (10 / 44), style: .continuous)
    }

    private var fallbackView: some View {
        GradientBackground(shape: shape, size: size)
            .overlay {
                Image(systemName: "building.2.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.5, height: size * 0.94)
                    .foregroundStyle(.white)
            }
    }
}
