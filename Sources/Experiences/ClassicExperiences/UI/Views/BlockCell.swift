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

class BlockCell: UICollectionViewCell {
    var block: ClassicBlock?
    
    var content: UIView? {
        return nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundView = UIImageView()
        clipsToBounds = true
        
        if let content = content {
            contentView.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        backgroundView = UIImageView()
        clipsToBounds = true
        
        if let content = content {
            contentView.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    func configure(with block: ClassicBlock) {
        self.block = block
        
        configureBackgroundColor()
        configureBackgroundImage()
        configureBorder()
        configureOpacity()
        configureContent()
        configureA11yTraits()
    }
    
    func configureBackgroundColor() {
        self.configureBackgroundColor(color: block?.background.color, opacity: block?.opacity)
    }
    
    func configureBackgroundImage() {
        guard let backgroundImageView = backgroundView as? UIImageView else {
            return
        }
        
        let originalBlockId = block?.id
        backgroundImageView.configureAsBackgroundImage(background: block?.background) { [weak self] in
            // Verify the block cell is still configured to the same block; otherwise we should no-op because the cell has been recycled.
            return self?.block?.id == originalBlockId
        }
    }
    
    func configureBorder() {
        self.configureBorder(border: block?.border, constrainedByFrame: self.frame)
    }
    
    func configureOpacity() {
        self.contentView.configureOpacity(opacity: block?.opacity)
    }
    
    func configureContent() {
        guard let block = block, let content = content else {
            return
        }
        
        self.contentView.configureContent(content: content, withInsets: block.insets)
    }
    
    func configureA11yTraits() {
        guard let block = block else {
            return
        }
        
        // if no inner content, then apply the a11y traits to the cell itself.
        let view = content ?? self
        
        guard !(block is ClassicTextPollBlock), !(block is ClassicImagePollBlock), !(block is ClassicWebViewBlock) else {
            // Polls and WebViews implement their own accessibility.
            return
        }
        
        // true if the block is an image and is marked as isDecorative.
        let isImageWithoutContent = ((block as? ClassicImageBlock)?.image.isDecorative) ?? false
        
        // Some Rover blocks should not be visible to accessibility:
        let hasContent = !(block is ClassicRectangleBlock) && !isImageWithoutContent
        
        // All Rover blocks that have meaningful content should be a11y, or if they at least have tap behaviour.
        view.isAccessibilityElement = hasContent || block.tapBehavior != .none
        
        // TabBehavior is mapped to the `link` accessibility trait:
        switch block.tapBehavior {
        case .goToScreen(_), .openURL(_, _), .presentWebsite(_):
            view.accessibilityTraits.applyTrait(trait: .link, to: true)
        default:
            view.accessibilityTraits.applyTrait(trait: .link, to: false)
        }
    }
}
