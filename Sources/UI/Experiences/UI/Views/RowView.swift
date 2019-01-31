//
//  RowView.swift
//  RoverUI
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

open class RowView: UICollectionReusableView {
    public let backgroundImageView = UIImageView()
    
    public var row: Row?
    
    open override var clipsToBounds: Bool {
        get {
            return true
        }
        // We want to override super's setter with a no-op.
        // swiftlint:disable:next unused_setter_value
        set { }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addSubviews()
    }
    
    open func addSubviews() {
        addSubview(backgroundImageView)
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        backgroundImageView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        backgroundImageView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        backgroundImageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    }
    
    open func configure(with row: Row, imageStore: ImageStore) {
        self.row = row
        
        configureBackgroundColor()
        configureBackgroundImage(imageStore: imageStore)
    }
    
    open func configureBackgroundColor() {
        guard let row = row else {
            backgroundColor = UIColor.clear
            return
        }
        
        backgroundColor = row.background.color.uiColor
    }
    
    // Function is decently 
    // swiftlint:disable:next cyclomatic_complexity
    open func configureBackgroundImage(imageStore: ImageStore) {
        
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
        
        guard let configuration = ImageConfiguration(background: row.background, frame: frame) else {
            return
        }
        
        if let image = imageStore.fetchedImage(for: configuration) {
            if case .tile = row.background.contentMode {
                backgroundImageView.backgroundColor = UIColor(patternImage: image)
            } else {
                backgroundImageView.image = image
            }
            backgroundImageView.alpha = 1.0
        } else {
            imageStore.fetchImage(for: configuration) { [weak self, rowID = row.id] image in
                guard let image = image else {
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
                
                UIView.animate(withDuration: 0.25, animations: {
                    self?.backgroundImageView.alpha = 1.0
                })
            }
        }
    }
}
