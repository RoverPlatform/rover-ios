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

extension String {
    func attributedForLinks(whiteLinks: Bool) -> AttributedString {
        var attributed = AttributedString(self)
        let linkColor: Color = whiteLinks ? .white : Color(uiColor: .link)

        let matches = Self.linkDetector.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
        for match in matches {
            guard let swiftRange = Range(match.range, in: self),
                let attributedRange = Range(swiftRange, in: attributed)
            else { continue }

            let url: URL?
            if let matchURL = match.url {
                url = matchURL
            } else if let phone = match.phoneNumber {
                let phoneDigits = phone.filter { $0.isNumber || $0 == "+" }
                // tel: has no authority component per RFC 3966 — no "//" prefix
                url = URL(string: "tel:\(phoneDigits)")
            } else {
                url = nil
            }

            guard let resolvedURL = url else { continue }

            attributed[attributedRange].link = resolvedURL
            attributed[attributedRange].foregroundColor = linkColor
        }

        return attributed
    }

    private static let linkDetector: NSDataDetector = try! NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
            | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
    )
}
