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
import UIKit



struct FontModifier: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.experience) private var experience
    @State private var uiFont: SwiftUI.Font

    var font: RoverExperiences.Font

    init(font: RoverExperiences.Font,
         experience: ExperienceModel?) {
        self.font = font
        self._uiFont =
            .init(initialValue: getUIFont(
                for: font,
                experience: experience))
    }

    func body(content: Content) -> some View {
        content
            .font(uiFont)
            .onReceive(NotificationCenter.default.publisher(for: ExperienceManager.didRegisterCustomFontNotification)) { _ in
                uiFont = getUIFont(for: font,
                                   experience: experience)
            }
    }
}


private func getUIFont(for font: RoverExperiences.Font,
                       experience: ExperienceModel?) -> SwiftUI.Font {
    if let uifont = font.uikitFont(with: experience) {        
        return SwiftUI.Font(uifont)
    }

    return .body
}


