//
//  WebViewCell.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import WebKit

class WebViewCell: BlockCell {
    let webView = WKWebView()
    
    override var content: UIView? {
        return webView
    }
    
    override func configure(with block: Block) {
        super.configure(with: block)
        
        guard let webViewBlock = block as? WebViewBlock else {
            self.webView.isHidden = true
            return
        }
        
        self.webView.isHidden = false
        
        let webView = webViewBlock.webView
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        self.webView.scrollView.backgroundColor = .clear
        self.webView.scrollView.isScrollEnabled = webView.isScrollingEnabled
        self.webView.scrollView.bounces = webView.isScrollingEnabled
        let request = URLRequest(url: webView.url)
        self.webView.load(request)
    }
}
