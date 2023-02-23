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

class BarcodeCell: BlockCell {
    let imageView: UIImageView = {
        let imageView = UIImageView()

        // Using stretch fit because we've ensured that the image will scale aspect-correct, so will always have the
        // correct aspect ratio (because auto-height will be always on), and we also are using integer scaling to ensure
        // a sharp scale of the pixels.  While we could use .scaleToFit, .scaleToFill will avoid the barcode
        // leaving any unexpected gaps around the outside in case of lack of agreement.
        imageView.contentMode = .scaleToFill
        
        imageView.accessibilityLabel = "Barcode"
        
        #if swift(>=4.2)
        imageView.layer.magnificationFilter = CALayerContentsFilter.nearest
        #else
        imageView.layer.magnificationFilter = kCAFilterNearest
        #endif
        
        return imageView
    }()
    
    override var content: UIView? {
        return imageView
    }
    
    override func configure(with block: ClassicBlock) {
        super.configure(with: block)
        
        guard let barcodeBlock = block as? ClassicBarcodeBlock else {
            imageView.isHidden = true
            return
        }
        
        imageView.isHidden = false
        imageView.image = nil

        let barcode = barcodeBlock.barcode

        guard let barcodeImage = barcode.cgImage else {
            imageView.image = nil
            return
        }

        imageView.image = UIImage(cgImage: barcodeImage)
    }
}
