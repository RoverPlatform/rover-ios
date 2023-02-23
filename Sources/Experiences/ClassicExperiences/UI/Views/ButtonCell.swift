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

class ButtonCell: BlockCell {
    let label = UILabel()
    
    override var content: UIView? {
        return label
    }
    
    override func configure(with block: ClassicBlock) {
        super.configure(with: block)
        
        guard let buttonBlock = block as? ClassicButtonBlock else {
            label.isHidden = true
            return
        }
        
        label.isHidden = false
        
        let text = buttonBlock.text
        label.highlightedTextColor = text.color.uiColor.withAlphaComponent(0.5 * text.color.uiColor.cgColor.alpha)
        label.text = text.rawValue
        label.textColor = text.color.uiColor
        label.textAlignment = text.alignment.textAlignment
        label.font = text.font.uiFont
        label.accessibilityTraits.applyTrait(trait: .button, to: true)
    }
}
