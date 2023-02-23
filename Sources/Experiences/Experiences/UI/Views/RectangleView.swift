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


struct RectangleView: View {
    var rectangle: RoverExperiences.Rectangle
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    @ViewBuilder
    var body: some View {
        // For some reason SwiftUI's Rectangle will not allow you apply both a fill and a border so
        // we must use a ZStack to apply both. The trailing compositingGroup modifier ensures that
        // the ShadowModifier renders properly.
        SwiftUI.ZStack {
            switch rectangle.fill {
            case .flat(let color):
                RealizeColor(color) { color in
                    RoundedRectangle(
                        cornerRadius: CGFloat(rectangle.cornerRadius),
                        style: .circular
                    )
                    .fill(color)
                }
                
            case .gradient(let gradientReference):
                RealizeGradient(gradientReference) { gradient in
                    RoundedRectangle(
                        cornerRadius: CGFloat(rectangle.cornerRadius),
                        style: .circular
                    )
                    .fill(gradient.swiftUIGradient())
                }
            }
            
            if let border = rectangle.border {
                RealizeColor(border.color) { borderColor in
                    RoundedRectangle(
                        cornerRadius: CGFloat(rectangle.cornerRadius),
                        style: .circular
                    )
                    .strokeBorder(lineWidth: CGFloat(border.width), antialiased: true)
                    .foregroundColor(borderColor)
                }
            }
        }
        .compositingGroup()
    }
}
