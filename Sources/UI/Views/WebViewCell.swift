//
//  WebViewCell.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import WebKit

open class WebViewCell: BlockCell {
    public let webView = WKWebView()
    
    override open var content: UIView? {
        return webView
    }
    
    override open func configure(with block: Block, imageStore: ImageStore) {
        super.configure(with: block, imageStore: imageStore)
        
        guard let webViewBlock = block as? WebViewBlock else {
            self.webView.isHidden = true
            return
        }
        
        self.webView.isHidden = false
        
        let webView = webViewBlock.webView
        self.webView.scrollView.isScrollEnabled = webView.isScrollingEnabled
        self.webView.scrollView.bounces = webView.isScrollingEnabled
        let request = URLRequest(url: webView.url)
        self.webView.load(request)
    }
}
