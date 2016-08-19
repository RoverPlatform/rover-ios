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
        case Normal, Highlighted, Selected, Disabled
    }
    
    private var titles: [State: NSAttributedString] = [.Normal: NSAttributedString(string: "")]
    private var titleColors: [State: UIColor] = [.Normal: UIColor.blackColor()]
    private var titleAlignments: [State: Alignment] = [.Normal: Alignment()] // default should be center middle
    private var titleOffsets: [State: Offset] = [.Normal: Offset()]
    private var titleFonts: [State: UIFont] = [.Normal: UIFont.systemFontOfSize(12)]
    private var backgroundColors: [State: UIColor] = [.Normal: UIColor.clearColor()]
    private var borderColors: [State: UIColor] = [.Normal: UIColor.clearColor()]
    private var borderWidths: [State: CGFloat] = [.Normal: 0]
    private var cornerRadii: [State: CGFloat] = [.Normal: 0]
    
    private var currentState: State = .Normal {
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
                userInteractionEnabled = true
                if currentState == .Disabled {
                    currentState = .Normal
                }
            } else if !enabled {
                userInteractionEnabled = false
                currentState = .Disabled
            }
        }
    }
    

    
    func setTitle(title: NSAttributedString?, forState state: UIControlState) {
        titles[state.buttonBlockViewCellState] = title
        updateTitle()
    }
    
    func setTitleColor(color: UIColor?, forState state: UIControlState) {
        titleColors[state.buttonBlockViewCellState] = color
        updateTitleColor()
    }
    
    func setTitleAlignment(alignment: Alignment?, forState state: UIControlState) {
        titleAlignments[state.buttonBlockViewCellState] = alignment
        updateTitleAlignment()
    }
    
    func setTitleOffset(offset: Offset?, forState state: UIControlState) {
        titleOffsets[state.buttonBlockViewCellState] = offset
        updateTitleOffset()
    }
    
    func setTitleFont(font: UIFont?, forState state: UIControlState) {
        titleFonts[state.buttonBlockViewCellState] = font
        updateTitleFont()
    }
    
    func setBackgroundColor(color: UIColor?, forState state: UIControlState) {
        backgroundColors[state.buttonBlockViewCellState] = color
        updateBackgroundColor()
    }
    
    func setBorderColor(color: UIColor?, forState state: UIControlState) {
        borderColors[state.buttonBlockViewCellState] = color
        updateBorderColor()
    }
    
    func setBorderWidth(width: CGFloat?, forState state: UIControlState) {
        borderWidths[state.buttonBlockViewCellState] = width
        updateBorderWidth()
    }
    
    func setCornerRadius(radius: CGFloat?, forState state: UIControlState) {
        cornerRadii[state.buttonBlockViewCellState] = radius
        updateCornerRadius()
    }
    
    private func updateTitle() {
        text = titles[currentState] ?? titles[.Normal]
    }
    
    private func updateTitleColor() {
        textColor = titleColors[currentState] ?? titleColors[.Normal] ?? textColor
    }
    
    private func updateTitleAlignment() {
        textAlignment = titleAlignments[currentState] ?? titleAlignments[.Normal] ?? textAlignment
    }
    
    private func updateTitleOffset() {
        textOffset = titleOffsets[currentState] ?? titleOffsets[.Normal] ?? textOffset
    }
    
    private func updateTitleFont() {
        font = titleFonts[currentState] ?? titleFonts[.Normal] ?? font
    }
    
    private func updateBackgroundColor() {
        backgroundColor = backgroundColors[currentState] ?? backgroundColors[.Normal]
    }
    
    private func updateBorderColor() {
        layer.borderColor = borderColors[currentState]?.CGColor ?? borderColors[.Normal]?.CGColor
    }
    
    private func updateBorderWidth() {
        layer.borderWidth = borderWidths[currentState] ?? borderWidths[.Normal] ?? layer.borderWidth
    }
    
    private func updateCornerRadius() {
        layer.cornerRadius = cornerRadii[currentState] ?? cornerRadii[.Normal] ?? layer.cornerRadius
    }
    
    
    override func didTouchDown() {
        currentState = .Highlighted
    }
    
    override func didEndTouch() {
        currentState = .Normal
    }
    
    override func didCancelTouch() {
        currentState = .Normal
    }
    
}

private extension UIControlState {
    var buttonBlockViewCellState: ButtonBlockViewCell.State {
        switch self {
        case UIControlState.Highlighted:
            return .Highlighted
        case UIControlState.Selected:
            return .Selected
        case UIControlState.Disabled:
            return .Disabled
        default:
            return .Normal
        }
    }
}