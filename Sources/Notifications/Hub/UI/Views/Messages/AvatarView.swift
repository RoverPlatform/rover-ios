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

struct AvatarView: View {
    let url: URL?
    let initials: String?
    let size: CGFloat

    init(
        url: URL?,
        name: String?,
        size: CGFloat = 44,
    ) {
        self.url = url
        self.initials = name?.initials
        self.size = size
    }

    var body: some View {
        RemoteImageView(url: url, size: size, shape: Circle()) {
            fallbackView
        }
    }

    private var fallbackView: some View {
        GradientBackground(shape: Circle(), size: size)
            .overlay {
                if let initials, !initials.isEmpty {
                    Text(initials)
                        .font(initialsFont)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.94, height: size * 0.94)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .clear)
                }
            }
    }

    private var initialsFont: Font {
        if size >= 40 {
            return .system(size: size * 0.38, weight: .semibold)
        }
        return .caption2.bold()
    }
}
