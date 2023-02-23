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

class ImagePollOptionOverlay: UIView {
    let fillBar: PollOptionFillBar
    let label = PollOptionPercentageLabel()
    let stackView = UIStackView()
    
    init(option: ClassicImagePollBlock.ImagePoll.Option) {
        fillBar = PollOptionFillBar(color: option.resultFillColor)
        super.init(frame: .zero)
        
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        // stackView
        
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        ])
        
        // label
        
        label.heightAnchor.constraint(equalToConstant: 24).isActive = true
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        stackView.addArrangedSubview(label)
        
        // fillBar
        
        fillBar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        fillBar.layer.cornerRadius = 4
        fillBar.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        stackView.addArrangedSubview(fillBar)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
