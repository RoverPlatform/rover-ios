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

import RoverUI
import UIKit

open class InboxCell: UITableViewCell {
    public var notification: Notification?
    
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open func configure(with notification: Notification, imageStore: ImageStore) {
        self.notification = notification
        
        configureBackgroundColor()
        configureTextLabel()
        configureDetailTextLabel()
        configureImage(imageStore: imageStore)
    }
    
    open func configureBackgroundColor() {
        guard let notification = notification else {
            #if swift(>=5.1)
            if #available(iOS 13.0, *) {
                backgroundColor = .systemBackground
            } else {
                backgroundColor = .white
            }
            #else
            backgroundColor = .white
            #endif
            return
        }
        
        #if swift(>=5.1)
        if #available(iOS 13.0, *) {
            backgroundColor = notification.isRead ? UIColor.systemBackground : UIColor.systemGray5
        } else {
            backgroundColor = notification.isRead ? UIColor.white : UIColor(red: 0.898039, green: 0.898039, blue: 0.917647, alpha: 1.0)
        }
        #else
        backgroundColor = notification.isRead ? UIColor.white : UIColor(red: 0.898039, green: 0.898039, blue: 0.917647, alpha: 1.0)
        #endif
    }
    
    open func configureTextLabel() {
        guard let textLabel = textLabel else {
            return
        }
        
        guard let notification = notification else {
            textLabel.text = ""
            return
        }
        
        textLabel.text = notification.body
    }
    
    open func configureDetailTextLabel() {
        guard let detailTextLabel = detailTextLabel else {
            return
        }
        
        guard let notification = notification else {
            detailTextLabel.text = ""
            return
        }
        
        detailTextLabel.text = notification.title
    }
    
    open func configureImage(imageStore: ImageStore) {
        guard let imageView = imageView else {
            return
        }
        
        imageView.alpha = 0.0
        imageView.image = nil
        
        guard let notification = notification, let attachment = notification.attachment, case .image = attachment.format else {
            return
        }
        
        let configuration = ImageConfiguration(url: attachment.url)
        
        if let image = imageStore.fetchedImage(for: configuration) {
            imageView.image = image
            imageView.alpha = 1.0
        } else {
            imageStore.fetchImage(for: configuration) { [weak self, weak imageView, notificationID = notification.id] image in
                guard let image = image else {
                    return
                }
                
                // Verify the notification cell is still configured to the same notification; otherwise we should no-op because the cell has been recycled.
                
                if self?.notification?.id != notificationID {
                    return
                }
                
                imageView?.image = image
                
                UIView.animate(withDuration: 0.25) {
                    imageView?.alpha = 1.0
                }
                
                self?.setNeedsLayout()
            }
        }
    }
}
