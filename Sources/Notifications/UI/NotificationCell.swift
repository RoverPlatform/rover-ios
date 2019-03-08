//
//  NotificationCell.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-04-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

open class NotificationCell: UITableViewCell {
    public var notification: Notification?
    
    #if swift(>=4.2)
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    #else
    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    #endif
    
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
            backgroundColor = UIColor.white
            return
        }
        
        backgroundColor = notification.isRead ? UIColor.white : UIColor.blue.withAlphaComponent(0.05)
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
