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

import UIKit

extension UIImageView {
    // swiftlint:disable:next cyclomatic_complexity // This routine is fairly readable as it is, so we will hold off on refactoring it, so silence the complexity warning.
    func configureAsBackgroundImage(background: ClassicBackground?, checkStillMatches: @escaping () -> Bool = { true }) {
        // Reset any existing background image
        
        self.alpha = 0.0
        self.image = nil
        
        self.isAccessibilityElement = background?.image.map { !$0.isDecorative } ?? false
        self.accessibilityLabel = background?.image?.accessibilityLabel
        
        // Background color is used for tiled backgrounds
        self.backgroundColor = UIColor.clear
        
        guard let background = background else {
            return
        }
        
        switch background.contentMode {
        case .fill:
            self.contentMode = .scaleAspectFill
        case .fit:
            self.contentMode = .scaleAspectFit
        case .original:
            self.contentMode = .center
        case .stretch:
            self.contentMode = .scaleToFill
        case .tile:
            self.contentMode = .center
        }
        
        if let image = ImageStore.shared.image(for: background, frame: frame) {
            if case .tile = background.contentMode {
                self.backgroundColor = UIColor(patternImage: image)
            } else {
                self.image = image
            }
            self.alpha = 1.0
        } else {
            let originalFrame = self.frame
            ImageStore.shared.fetchImage(for: background, frame: frame) { [weak self] image in
                guard let image = image, checkStillMatches(), self?.frame == originalFrame else {
                    return
                }
                
                if case .tile = background.contentMode {
                    self?.backgroundColor = UIColor(patternImage: image)
                } else {
                    self?.image = image
                }
                
                UIView.animate(withDuration: 0.25) {
                    self?.alpha = 1.0
                }
            }
        }
    }
}
