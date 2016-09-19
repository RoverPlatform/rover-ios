//
//  ButtonBlockViewCell.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-06.
//
//

import UIKit



class ButtonBlockViewCell: TextBlockViewCell {
    
    enum State {
        case normal, highlighted, selected, disabled
    }
    
    fileprivate var titles: [State: NSAttributedString] = [.normal: NSAttributedString(string: "")]
    fileprivate var titleColors: [State: UIColor] = [.normal: UIColor.black]
    fileprivate var titleAlignments: [State: Alignment] = [.normal: Alignment()] // default should be center middle
    fileprivate var titleOffsets: [State: Offset] = [.normal: Offset()]
    fileprivate var titleFonts: [State: UIFont] = [.normal: UIFont.systemFont(ofSize: 12)]
    fileprivate var backgroundColors: [State: UIColor] = [.normal: UIColor.clear]
    fileprivate var borderColors: [State: UIColor] = [.normal: UIColor.clear]
    fileprivate var borderWidths: [State: CGFloat] = [.normal: 0]
    fileprivate var cornerRadii: [State: CGFloat] = [.normal: 0]
    
    fileprivate var currentState: State = .normal {
        didSet {
            updateTitle()
            updateTitleFont()
            updateTitleOffset()
            updateTitleAlignment()
            updateTitleColor()
            updateBackgroundColor()
            updateBorderColor()
            updateBorderWidth()
            updateCornerRadius()
        }
    }
    
    var enabled: Bool = true {
        didSet {
            if enabled {
                isUserInteractionEnabled = true
                if currentState == .disabled {
                    currentState = .normal
                }
            } else if !enabled {
                isUserInteractionEnabled = false
                currentState = .disabled
            }
        }
    }
    

    
    func setTitle(_ title: NSAttributedString?, forState state: UIControlState) {
        titles[state.buttonBlockViewCellState] = title
        updateTitle()
    }
    
    func setTitleColor(_ color: UIColor?, forState state: UIControlState) {
        titleColors[state.buttonBlockViewCellState] = color
        updateTitleColor()
    }
    
    func setTitleAlignment(_ alignment: Alignment?, forState state: UIControlState) {
        titleAlignments[state.buttonBlockViewCellState] = alignment
        updateTitleAlignment()
    }
    
    func setTitleOffset(_ offset: Offset?, forState state: UIControlState) {
        titleOffsets[state.buttonBlockViewCellState] = offset
        updateTitleOffset()
    }
    
    func setTitleFont(_ font: UIFont?, forState state: UIControlState) {
        titleFonts[state.buttonBlockViewCellState] = font
        updateTitleFont()
    }
    
    func setBackgroundColor(_ color: UIColor?, forState state: UIControlState) {
        backgroundColors[state.buttonBlockViewCellState] = color
        updateBackgroundColor()
    }
    
    func setBorderColor(_ color: UIColor?, forState state: UIControlState) {
        borderColors[state.buttonBlockViewCellState] = color
        updateBorderColor()
    }
    
    func setBorderWidth(_ width: CGFloat?, forState state: UIControlState) {
        borderWidths[state.buttonBlockViewCellState] = width
        updateBorderWidth()
    }
    
    func setCornerRadius(_ radius: CGFloat?, forState state: UIControlState) {
        cornerRadii[state.buttonBlockViewCellState] = radius
        updateCornerRadius()
    }
    
    fileprivate func updateTitle() {
        text = titles[currentState] ?? titles[.normal]
    }
    
    fileprivate func updateTitleColor() {
        textColor = titleColors[currentState] ?? titleColors[.normal] ?? textColor
    }
    
    fileprivate func updateTitleAlignment() {
        textAlignment = titleAlignments[currentState] ?? titleAlignments[.normal] ?? textAlignment
    }
    
    fileprivate func updateTitleOffset() {
        textOffset = titleOffsets[currentState] ?? titleOffsets[.normal] ?? textOffset
    }
    
    fileprivate func updateTitleFont() {
        font = titleFonts[currentState] ?? titleFonts[.normal] ?? font
    }
    
    fileprivate func updateBackgroundColor() {
        backgroundColor = backgroundColors[currentState] ?? backgroundColors[.normal]
    }
    
    fileprivate func updateBorderColor() {
        layer.borderColor = borderColors[currentState]?.cgColor ?? borderColors[.normal]?.cgColor
    }
    
    fileprivate func updateBorderWidth() {
        layer.borderWidth = borderWidths[currentState] ?? borderWidths[.normal] ?? layer.borderWidth
    }
    
    fileprivate func updateCornerRadius() {
        layer.cornerRadius = cornerRadii[currentState] ?? cornerRadii[.normal] ?? layer.cornerRadius
    }
    
    
    override func didTouchDown() {
        currentState = .highlighted
    }
    
    override func didEndTouch() {
        currentState = .normal
    }
    
    override func didCancelTouch() {
        currentState = .normal
    }
    
}

private extension UIControlState {
    var buttonBlockViewCellState: ButtonBlockViewCell.State {
        switch self {
        case UIControlState.highlighted:
            return .highlighted
        case UIControlState.selected:
            return .selected
        case UIControlState.disabled:
            return .disabled
        default:
            return .normal
        }
    }
}
