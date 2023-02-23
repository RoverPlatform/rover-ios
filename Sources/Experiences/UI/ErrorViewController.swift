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

class ErrorViewController: UIViewController {
    let shouldRetry: Bool
    let retryHandler: (() -> Void)?
    
    let errorLabel = UILabel(frame: .zero)
    let retryButton = UIButton(type: .system)
    
    init(shouldRetry: Bool, retryHandler: (() -> Void)? = nil) {
        self.shouldRetry = shouldRetry
        self.retryHandler = retryHandler
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not implemented.")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        errorLabel.text = NSLocalizedString("Something went wrong", comment: "Rover Failed to load experience error message")
        errorLabel.textColor = .darkText
        errorLabel.textAlignment = .center
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(errorLabel)
        
        let layoutGuide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: layoutGuide.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: layoutGuide.centerYAnchor)
        ])
        
        if shouldRetry, let retryHandler = retryHandler {
            retryButton.setTitle(NSLocalizedString("Try Again", comment: "Rover Try Again Action"), for: .normal)
            retryButton.addAction(for: .touchUpInside) { _ in
                retryHandler()
            }
            retryButton.translatesAutoresizingMaskIntoConstraints = false
            
            view.addSubview(retryButton)
            
            NSLayoutConstraint.activate([
                retryButton.centerXAnchor.constraint(equalTo: layoutGuide.centerXAnchor),
                retryButton.topAnchor.constraint(lessThanOrEqualTo: errorLabel.bottomAnchor, constant: 8)
            ])
        }
    }
}
