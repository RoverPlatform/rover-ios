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

class TextCell: BlockCell {
    let textView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = UIColor.clear
        textView.isEditable = false
        // Prevent text selection, which is not appropriate for UI content.
        textView.isUserInteractionEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets.zero
        textView.isAccessibilityElement = true
        // a side-effect of userInteractionEnabled being false is Voice Over exclaiming "dimmed!".
        textView.accessibilityTraits.applyTrait(trait: .notEnabled, to: false)
        return textView
    }()
    
    override var content: UIView? {
        return textView
    }
    
    private var currentBlockID: String?
    
    override func configure(with block: ClassicBlock) {
        super.configure(with: block)

        guard let textBlock = block as? ClassicTextBlock else {
            textView.isHidden = true
            return
        }
        
        textView.isHidden = false
        self.currentBlockID = block.id
        
        // NSAttributedString, when initialized with the HTML options that we use, internally uses WebKit/NSHTMLReader. These have internal async operations that can synchronously run a mainloop tick, but given that configure() is running in the context of func collectionView(:, cellForItemAt:), this could potentially cause NSInternalConsistencyException under certain conditions.
        DispatchQueue.main.async { [weak self] in
            // check that this callback isn't stale, and would clobber a configure() that has occurred since.
            guard let self = self, block.id == self.currentBlockID else {
                return
            }
            
            textView.attributedText = textBlock.text.attributedText(forFormat: .html)
        }
    }
}
