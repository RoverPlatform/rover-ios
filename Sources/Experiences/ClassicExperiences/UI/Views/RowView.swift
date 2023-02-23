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

class RowView: UICollectionReusableView {
    let backgroundImageView = UIImageView()
    
    var row: ClassicRow?
    
    override var clipsToBounds: Bool {
        get {
            return true
        }
        // swiftlint:disable:next unused_setter_value // we are overriding with a no-effect setter here.
        set { }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addSubviews()
    }
    
    func addSubviews() {
        addSubview(backgroundImageView)
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        backgroundImageView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        backgroundImageView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        backgroundImageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    }
    
    func configure(with row: ClassicRow) {
        self.row = row
        
        configureBackgroundColor()
        configureBackgroundImage()
    }
    
    func configureBackgroundColor() {
        guard let row = row else {
            backgroundColor = UIColor.clear
            return
        }
        
        backgroundColor = row.background.color.uiColor
    }
    
    // swiftlint:disable:next cyclomatic_complexity // This routine is fairly readable as it is, so we will hold off on refactoring it, so silence the complexity warning.
    func configureBackgroundImage() {
        // Reset any existing background image
        
        backgroundImageView.alpha = 0.0
        backgroundImageView.image = nil
        
        // Background color is used for tiled backgrounds
        backgroundImageView.backgroundColor = UIColor.clear
        
        guard let row = row else {
            return
        }
        
        switch row.background.contentMode {
        case .fill:
            backgroundImageView.contentMode = .scaleAspectFill
        case .fit:
            backgroundImageView.contentMode = .scaleAspectFit
        case .original:
            backgroundImageView.contentMode = .center
        case .stretch:
            backgroundImageView.contentMode = .scaleToFill
        case .tile:
            backgroundImageView.contentMode = .center
        }
        
        if let image = ImageStore.shared.image(for: row.background, frame: frame) {
            if case .tile = row.background.contentMode {
                backgroundImageView.backgroundColor = UIColor(patternImage: image)
            } else {
                backgroundImageView.image = image
            }
            backgroundImageView.alpha = 1.0
        } else {
            let originalFrame = self.frame
            ImageStore.shared.fetchImage(for: row.background, frame: frame) { [weak self, rowID = row.id] image in
                guard let image = image, self?.frame == originalFrame else {
                    return
                }
                
                // Verify the block cell is still configured to the same block; otherwise we should no-op because the cell has been recycled.
                
                if self?.row?.id != rowID {
                    return
                }
                
                if case .tile = row.background.contentMode {
                    self?.backgroundImageView.backgroundColor = UIColor(patternImage: image)
                } else {
                    self?.backgroundImageView.image = image
                }
                
                UIView.animate(withDuration: 0.25) {
                    self?.backgroundImageView.alpha = 1.0
                }
            }
        }
    }
}
