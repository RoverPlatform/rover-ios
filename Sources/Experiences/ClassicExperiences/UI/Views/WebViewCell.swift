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

import WebKit

class WebViewCell: BlockCell {
    let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration.roverDefault)
    
    override var content: UIView? {
        return webView
    }
    
    override func configure(with block: ClassicBlock) {
        super.configure(with: block)
        
        guard let webViewBlock = block as? ClassicWebViewBlock else {
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

extension WKWebViewConfiguration {
    static var roverDefault: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        return config
    }
}
