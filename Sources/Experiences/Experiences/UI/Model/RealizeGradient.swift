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


/// Realize a GradientReference into a SwiftUI view that renders the the gradient, accounting for the DocumentGradients getting updated.
struct RealizeGradient<Content>: View where Content: View {
    var gradientReference: GradientReference?
    var content: (GradientValue) -> Content
    
    init(_ gradientReference: GradientReference? = nil, @ViewBuilder content: @escaping (GradientValue) -> Content) {
        self.gradientReference = gradientReference
        self.content = content
    }
    
    @ViewBuilder
    var body: some View {
        switch gradientReference?.referenceType {
        case .custom:
            if let gradientValue = gradientReference?.customGradient {
                content(gradientValue)
            }
        case .document:
            if let documentGradient = gradientReference?.documentGradient {
                ObserveDocumentGradient(documentGradient: documentGradient, content: content)
            }
        case nil:
            content(.clear)
        }
    }
}

private struct ObserveDocumentGradient<Content>: View where Content: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    // for now, we aren't able to set color scheme contrast, so we just use the preview setting directly.
    //    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    
    var documentGradient: DocumentGradient
    
    var content: (GradientValue) -> Content
    
    var body: some View {
        content(
            documentGradient.resolveGradient(
                darkMode: colorScheme == .dark,
                highContrast: colorSchemeContrast == .increased
            )
        )
    }
}
