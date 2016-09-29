//
//  UIImageView+RVAsset.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-30.
//
//

import UIKit

extension UIImageView {
    
    func rv_setImage(url: URL) {
        AssetManager.sharedManager.fetchAsset(url: url) { (data) in
            guard let data = data else { return }
            
            self.image = UIImage(data: data)
        }
    }
    
    func rv_setImage(url: URL?, activityIndicatorStyle: UIActivityIndicatorViewStyle) {
        guard let url = url else {
            image = nil
            return
        }
        
        let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: activityIndicatorStyle)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(activityIndicatorView)
        
        addConstraints([
            NSLayoutConstraint(item: activityIndicatorView, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: activityIndicatorView, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0)
            ])
        
        activityIndicatorView.startAnimating()
        
        AssetManager.sharedManager.fetchAsset(url: url) { (data) in
            defer {
                activityIndicatorView.stopAnimating()
            }
            
            guard let data = data else { return }
            
            self.image = UIImage(data: data)
        }
    }
}
