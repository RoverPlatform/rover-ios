//
//  WebBlockViewCell.swift
//  Pods
//
//  Created by Ata Namvari on 2016-08-12.
//
//

import Foundation

class WebBlockViewCell: BlockViewCell {
    var url: URL? {
        didSet {
            guard let url = url else {
                webview.loadRequest(URLRequest(url: URL(string: "about:blank")!))
                return
            }
            webview.loadRequest(URLRequest(url: url))
        }
    }
    
    fileprivate let webview = UIWebView()
    
    var scrollable = false {
        didSet {
            webview.scrollView.isScrollEnabled = scrollable
            webview.scrollView.bounces = scrollable
        }
    }
    
    override func commonInit() {
        webview.translatesAutoresizingMaskIntoConstraints = false
        webview.scrollView.isScrollEnabled = scrollable
        webview.scrollView.bounces = scrollable
        contentView.addSubview(webview)
        contentView.addConstraints([
            NSLayoutConstraint(item: webview, attribute: .leading, relatedBy: .equal, toItem: contentView, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: webview, attribute: .trailing, relatedBy: .equal, toItem: contentView, attribute: .trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: webview, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: webview, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1, constant: 0)
            ])
    }
}
