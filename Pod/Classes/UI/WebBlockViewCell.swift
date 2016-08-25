//
//  WebBlockViewCell.swift
//  Pods
//
//  Created by Ata Namvari on 2016-08-12.
//
//

import Foundation

class WebBlockViewCell: BlockViewCell {
    var url: NSURL? {
        didSet {
            guard let url = url else {
                webview.loadRequest(NSURLRequest(URL: NSURL(string: "about:blank")!))
                return
            }
            webview.loadRequest(NSURLRequest(URL: url))
        }
    }
    
    private let webview = UIWebView()
    
    var scrollable = false {
        didSet {
            webview.scrollView.scrollEnabled = scrollable
            webview.scrollView.bounces = scrollable
        }
    }
    
    override func commonInit() {
        webview.translatesAutoresizingMaskIntoConstraints = false
        webview.scrollView.scrollEnabled = scrollable
        webview.scrollView.bounces = scrollable
        contentView.addSubview(webview)
        contentView.addConstraints([
            NSLayoutConstraint(item: webview, attribute: .Leading, relatedBy: .Equal, toItem: contentView, attribute: .Leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: webview, attribute: .Trailing, relatedBy: .Equal, toItem: contentView, attribute: .Trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: webview, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: webview, attribute: .Bottom, relatedBy: .Equal, toItem: contentView, attribute: .Bottom, multiplier: 1, constant: 0)
            ])
    }
}