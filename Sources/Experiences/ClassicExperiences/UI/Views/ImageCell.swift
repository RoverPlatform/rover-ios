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

class ImageCell: BlockCell {
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        return imageView
    }()
    
    override var content: UIView? {
        return imageView
    }
    
    override func configure(with block: ClassicBlock) {
        super.configure(with: block)
        
        guard let imageBlock = block as? ClassicImageBlock else {
            imageView.isHidden = true
            return
        }
        
        imageView.alpha = 0.0
        imageView.image = nil
        
        imageView.accessibilityLabel = imageBlock.image.accessibilityLabel
                
        if let image = ImageStore.shared.image(for: imageBlock.image, frame: frame) {
            imageView.image = image
            imageView.alpha = 1.0
        } else {
            ImageStore.shared.fetchImage(for: imageBlock.image, frame: frame) { [weak self, blockID = block.id] image in
                guard let image = image else {
                    return
                }
                
                // Verify the block cell is still configured to the same block; otherwise we should no-op because the cell has been recycled.
                
                if self?.block?.id != blockID {
                    return
                }
                
                self?.imageView.image = image
                
                UIView.animate(withDuration: 0.25) {
                    self?.imageView.alpha = 1.0
                }
            }
        }
    }
}
