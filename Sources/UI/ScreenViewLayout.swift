//
//  ScreenViewLayout.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit
import os

// swiftlint:disable:next type_body_length
class ScreenViewLayout: UICollectionViewLayout {
    let screen: Screen
    
    var needsPreparation = true
    var height: CGFloat = 0
    
    typealias AttributesMap = [IndexPath: ScreenLayoutAttributes]
    
    var blockAttributesMap = AttributesMap()
    var rowAttributesMap = AttributesMap()
    
    init(screen: Screen) {
        self.screen = screen
        super.init()
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var collectionViewContentSize: CGSize {
        guard let collectionView = self.collectionView else {
            return CGSize.zero
        }
        
        return CGSize(width: collectionView.frame.width, height: height)
    }
    
    override func prepare() {
        guard needsPreparation else {
            return
        }
        
        prepare(frame: collectionView!.frame)
        needsPreparation = false
    }
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func prepare(frame: CGRect) {
        var rowAttributesMap = AttributesMap()
        var blockAttributesMap = AttributesMap()
        
        var totalHeight: CGFloat = 0
        
        struct PartialRect {
            let x: CGFloat
            let y: CGFloat?
            let width: CGFloat
            let height: CGFloat?
        }
        
        for (i, row) in screen.rows.enumerated() {
            let rowX: CGFloat = 0
            let rowY = totalHeight
            let rowWidth = frame.width
            
            var firstPass = [IndexPath: PartialRect]()
            var stackedHeight: CGFloat = 0
            
            // First pass
            
            for (j, block) in row.blocks.enumerated() {
                let blockX: CGFloat = {
                    switch block.position.horizontalAlignment {
                    case let .center(offset, width):
                        return rowX + ((rowWidth - CGFloat(width)) / 2) + CGFloat(offset)
                    case let .fill(leftOffset, _):
                        return rowX + CGFloat(leftOffset)
                    case let .left(offset, _):
                        return rowX + CGFloat(offset)
                    case let .right(offset, width):
                        return rowX + rowWidth - CGFloat(width) - CGFloat(offset)
                    }
                }()
                
                let blockY: CGFloat? = {
                    switch block.position.verticalAlignment {
                    case .fill(let topOffset, _):
                        return rowY + CGFloat(topOffset)
                    case .stacked(let topOffset, _, _):
                        return rowY + stackedHeight + CGFloat(topOffset)
                    case .top(let offset, _):
                        return rowY + CGFloat(offset)
                    default:
                        return nil
                    }
                }()
                
                let blockWidth: CGFloat = {
                    switch block.position.horizontalAlignment {
                    case .center(_, let width):
                        return CGFloat(width)
                    case let .fill(leftOffset, rightOffset):
                        return rowWidth - CGFloat(leftOffset) - CGFloat(rightOffset)
                    case let .left(_, width):
                        return CGFloat(width)
                    case .right(_, let width):
                        return CGFloat(width)
                    }
                }()
                
                // MARK: Block Measurement
                
                let intrinsicHeight: CGFloat?
                switch block {
                case let block as BarcodeBlock:
                    guard let renderedBitmap = block.barcode.cgImage else {
                        // barcode was not renderable, so intrinsic height will be 0.
                        intrinsicHeight = 0
                        break
                    }
                    
                    let aspectRatio = CGFloat(renderedBitmap.width) / CGFloat(renderedBitmap.height)
                    
                    intrinsicHeight = blockWidth / aspectRatio
                case let block as ButtonBlock:
                    guard let attributedText = block.text.attributedText() else {
                        intrinsicHeight = nil
                        break
                    }
                    
                    let innerWidth = blockWidth - CGFloat(block.insets.left) - CGFloat(block.insets.right)
                    let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)
                    let boundingRect = attributedText.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    intrinsicHeight = boundingRect.height + CGFloat(block.insets.top) + CGFloat(block.insets.bottom)
                case let block as ImageBlock:
                    let aspectRatio = CGFloat(block.image.width) / CGFloat(block.image.height)
                    intrinsicHeight = blockWidth / aspectRatio
                case let block as TextBlock:
                    guard let attributedText = block.text.attributedText() else {
                        intrinsicHeight = nil
                        break
                    }
                    
                    let innerWidth = blockWidth - CGFloat(block.insets.left) - CGFloat(block.insets.right)
                    let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)
                    let boundingRect = attributedText.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    intrinsicHeight = boundingRect.height + CGFloat(block.insets.top) + CGFloat(block.insets.bottom)
                case let block as TextPollBlock:
                    // blocks need to be measured.
                    intrinsicHeight = block.intrinsicHeight(blockWidth: blockWidth)
                case let block as ImagePollBlock:
                    intrinsicHeight = 4200
                default:
                    intrinsicHeight = nil
                }
                
                let heightFromType: (Height) -> CGFloat? = { heightType in
                    switch heightType {
                    case .intrinsic:
                        return intrinsicHeight
                    case .static(let value):
                        return CGFloat(value)
                    }
                }
                
                let blockHeight: CGFloat? = {
                    switch block.position.verticalAlignment {
                    case .bottom(_, let height):
                        return heightFromType(height)
                    case .middle(_, let height):
                        return heightFromType(height)
                    case .stacked(_, _, let height):
                        return heightFromType(height)
                    case .top(_, let height):
                        return heightFromType(height)
                    default:
                        return nil
                    }
                }()
                
                if case .stacked(let topOffset, let bottomOffset, _) = block.position.verticalAlignment, let blockHeight = blockHeight {
                    stackedHeight += CGFloat(topOffset) + blockHeight + CGFloat(bottomOffset)
                }
                
                let index = IndexPath(row: j, section: i)
                firstPass[index] = PartialRect(x: blockX, y: blockY, width: blockWidth, height: blockHeight)
            }
            
            let rowHeight: CGFloat
            switch row.height {
            case .intrinsic:
                rowHeight = stackedHeight
            case .static(let value):
                rowHeight = CGFloat(value)
            }
            
            let rowFrame = CGRect(x: rowX, y: rowY, width: rowWidth, height: rowHeight)
            let rowIndex = IndexPath(row: 0, section: i)
            let rowAttributes = ScreenLayoutAttributes(forSupplementaryViewOfKind: "row", with: rowIndex)
            rowAttributes.frame = rowFrame
            rowAttributes.referenceFrame = rowFrame
            rowAttributes.zIndex = 0
            rowAttributesMap[rowIndex] = rowAttributes
            
            totalHeight += rowHeight
            
            // Second pass
            
            for (j, block) in row.blocks.enumerated() {
                let blockIndex = IndexPath(row: j, section: i)
                let partialRect = firstPass[blockIndex]!
                
                let blockX = partialRect.x
                let blockWidth = partialRect.width
                
                let blockHeight = partialRect.height ?? {
                    guard case .fill(let topOffset, let bottomOffset) = block.position.verticalAlignment else {
                        return 0
                    }
                    
                    return rowHeight - CGFloat(topOffset) - CGFloat(bottomOffset)
                    }()
                
                let blockY = partialRect.y ?? {
                    switch block.position.verticalAlignment {
                    case .bottom(let offset, _):
                        return rowY + rowHeight - blockHeight - CGFloat(offset)
                    case .middle(let offset, _):
                        return rowY + ((rowHeight - blockHeight) / 2) + CGFloat(offset)
                    default:
                        fatalError("Vertical alignment must only be bottom or middle.")
                    }
                }()
                
                let blockFrame = CGRect(x: blockX, y: blockY, width: blockWidth, height: blockHeight)
                
                // if blockFrame exceeds the rowFrame, we need to clip it within the row, and in terms relative
                // to blockFrame.
                let clipRect: CGRect? = {
                    if !rowFrame.contains(blockFrame) {
                        // and find the intersection with blockFrame to find out what should be exposed and then
                        // transform into coordinate space with origin of the blockframe in the top left corner:
                        let intersection = rowFrame.intersection(blockFrame)
                        
                        // translate the clip to return the intersection, but if there is none that means the
                        // block is *entirely* outside of the bounds.  An unlikely but not impossible situation.
                        // Clip it entirely:
                        if intersection.isNull {
                            return CGRect(x: blockFrame.origin.x, y: blockFrame.origin.y, width: 0, height: 0)
                        } else {
                            // translate the rect into the terms of the containing rowframe:
                            return intersection.offsetBy(dx: 0 - blockFrame.origin.x, dy: 0 - blockFrame.origin.y)
                        }
                    } else {
                        // no clip is necessary because the blockFrame is contained entirely within the
                        // surrounding block.
                        return nil as CGRect?
                    }
                }()
                
                let blockAttributes = ScreenLayoutAttributes(forCellWith: blockIndex)
                blockAttributes.frame = blockFrame
                blockAttributes.referenceFrame = blockFrame
                blockAttributes.clipRect = clipRect

                blockAttributes.verticalAlignment = {
                    switch block.position.verticalAlignment {
                    case .bottom:
                        return .bottom
                    case .fill:
                        return .fill
                    case .middle:
                        return .center
                    case .stacked, .top:
                        return .top
                    }
                }()
                
                blockAttributes.zIndex = row.blocks.count - j
                blockAttributesMap[blockIndex] = blockAttributes
            }
        }
        
        self.height = totalHeight
        self.rowAttributesMap = rowAttributesMap
        self.blockAttributesMap = blockAttributesMap
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let rowAttributes = rowAttributesMap.filter { $0.1.frame.intersects(rect) }.map { $0.1 }
        let blockAttributes = blockAttributesMap.filter { $0.1.frame.intersects(rect) }.map { $0.1 }
        
        if !screen.isStretchyHeaderEnabled {
            return rowAttributes + blockAttributes
        }
        
        let offset: CGFloat
        if #available(iOS 11.0, *) {
            offset = collectionView!.contentOffset.y + collectionView!.adjustedContentInset.top
        } else {
            offset = collectionView!.contentOffset.y + collectionView!.contentInset.top
        }
        
        guard offset < 0 else {
            return rowAttributes + blockAttributes
        }
        
        var deltaY = abs(offset)
        
        // the UICollectionViewLayout may not query our shouldInvalidateLayout implementation when very
        // nearly near the top of overscroll (particularly, within one logical pixel), so pin it to zero if so.
        if deltaY < 1 {
           deltaY = 0
        }
        
        if let headerAttributes = rowAttributes.first(where: { $0.indexPath.section == 0 }) {
            var frame = headerAttributes.referenceFrame
            frame.size.height = max(0, frame.size.height + deltaY)
            frame.origin.y -= deltaY
            headerAttributes.frame = frame
        }
        
        blockAttributes.forEach { attributes in
            guard attributes.indexPath.section == 0 else {
                return
            }
            
            var frame = attributes.referenceFrame
            
            switch attributes.verticalAlignment {
            case .bottom:
                break
            case .center:
                frame.origin.y -= deltaY / 2
            case .fill:
                frame.origin.y -= deltaY
                frame.size.height += deltaY
            case .top:
                frame.origin.y -= deltaY
            @unknown default:
                os_log("Unexpected UIControl.ContentVerticalAlignment value type appeared: %@", String(describing: attributes.verticalAlignment))
                break
            }
            
            attributes.frame = frame
        }
        
        return rowAttributes + blockAttributes
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return blockAttributesMap[indexPath]
    }
    
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return rowAttributesMap[indexPath]
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        if !screen.isStretchyHeaderEnabled {
            return false
        }
        
        return newBounds.origin.y < 0 - collectionView!.contentInset.top
    }
}
