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

import Foundation
import SwiftUI
import UIKit

extension RoverExperiences.Font {
    func uikitFont(with experience: ExperienceModel?) -> UIFont? {
        switch self {
        case .dynamic(let textStyle, let emphases):
            let font = UIFont.preferredFont(forTextStyle: textStyle.uiTextStyle)
            return emphases.reduce(font) { currentFont, emphasis in
                // `withSymbolicTraits` replaces the trait set rather than merging,
                // so union with the traits accumulated so far or a bold+italic
                // combination keeps only the last emphasis applied.
                let combined = currentFont.fontDescriptor.symbolicTraits.union(emphasis.symbolicTrait)
                return currentFont.withTraits(traits: combined) ?? currentFont
            }

        case .fixed(let size, let weight):
            let scaledSize = UIFontMetrics.default.scaledValue(for: size)
            return UIFont.systemFont(ofSize: scaledSize, weight: weight.uiWeight)

        case .document(let fontFamily, let textStyle):
            let fontName: String
            let scaledSize: CGFloat

            if let experience = experience,
                let documentFont = experience.fonts.first(where: { $0.fontFamily == fontFamily })
            {
                let customFont = documentFont.fontForStyle(textStyle)
                fontName = customFont.fontName
                scaledSize = UIFontMetrics.default.scaledValue(for: customFont.size)
            } else {
                fontName = fontFamily
                scaledSize = UIFontMetrics.default.scaledValue(for: 14)
            }

            let font = UIFont(name: fontName, size: scaledSize)

            if font == nil {
                rover_log(
                    .debug,
                    "Missing font %@ (family %@) at %.1fpt, falling back to the system font",
                    fontName,
                    fontFamily,
                    Double(scaledSize)
                )
            }
            return font

        case .custom(let fontName, let size):
            let font = UIFont(name: fontName, size: size)

            if font == nil {
                rover_log(
                    .debug,
                    "Missing font %@ at %.1fpt, falling back to the system font",
                    fontName,
                    Double(size)
                )
            }
            return font
        }
    }
}

extension RoverExperiences.Font.Emphasis {
    fileprivate var symbolicTrait: UIFontDescriptor.SymbolicTraits {
        switch self {
        case .bold:
            return .traitBold
        case .italic:
            return .traitItalic
        }
    }
}

extension SwiftUI.Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title1
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .body:
            return .body
        case .callout:
            return .callout
        case .footnote:
            return .footnote
        case .caption:
            return .caption1
        case .caption2:
            return .caption2
        @unknown default:
            return .body
        }
    }
}

extension SwiftUI.Font.Weight {
    var uiWeight: UIFont.Weight {
        switch self {
        case .black:
            return .black
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .light:
            return .light
        case .medium:
            return .medium
        case .regular:
            return .regular
        case .semibold:
            return .semibold
        case .thin:
            return .thin
        case .ultraLight:
            return .ultraLight
        default:
            return .regular
        }
    }
}

private extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return nil
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
