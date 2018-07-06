//
//  ScreenViewLayout.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

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
    
    open func prepare(frame: CGRect) {
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
                    case .center(let offset, let width):
                        return rowX + ((rowWidth - CGFloat(width)) / 2) + CGFloat(offset)
                    case .fill(let leftOffset, _):
                        return rowX + CGFloat(leftOffset)
                    case .left(let offset, _):
                        return rowX + CGFloat(offset)
                    case .right(let offset, let width):
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
                    case .fill(let leftOffset, let rightOffset):
                        return rowWidth - CGFloat(leftOffset) - CGFloat(rightOffset)
                    case .left(_, let width):
                        return CGFloat(width)
                    case .right(_, let width):
                        return CGFloat(width)
                    }
                }()
                
                let intrinsicHeight: CGFloat? = {
                    switch block {
                    case let block as BarcodeBlock:
                        let aspectRatio: CGFloat = {
                            switch block.barcode.format {
                            case .aztecCode:
                                return CGFloat(1.0)
                            case .code128:
                                return CGFloat(2.26086956521739)
                            case .pdf417:
                                return CGFloat(2.25)
                            case .qrCode:
                                return CGFloat(1.0)
                            }
                        }()
                        return blockWidth / aspectRatio
                    case let block as ButtonBlock:
                        guard let attributedText = block.text.attributedText else {
                            return nil
                        }
                        
                        let innerWidth = blockWidth - CGFloat(block.insets.left) - CGFloat(block.insets.right)
                        let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)
                        let boundingRect = attributedText.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                        return boundingRect.height + CGFloat(block.insets.top) + CGFloat(block.insets.bottom)
                    case let block as ImageBlock:
                        let aspectRatio = CGFloat(block.image.width) / CGFloat(block.image.height)
                        return blockWidth / aspectRatio
                    case let block as TextBlock:
                        guard let attributedText = block.text.attributedText else {
                            return nil
                        }
                        
                        let innerWidth = blockWidth - CGFloat(block.insets.left) - CGFloat(block.insets.right)
                        let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)
                        let boundingRect = attributedText.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                        return boundingRect.height + CGFloat(block.insets.top) + CGFloat(block.insets.bottom)
                    default:
                        return nil
                    }
                }()
                
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
                        fatalError()
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
                        fatalError()
                    }
                }()
                
                let blockFrame = CGRect(x: blockX, y: blockY, width: blockWidth, height: blockHeight)
                let blockAttributes = ScreenLayoutAttributes(forCellWith: blockIndex)
                blockAttributes.frame = blockFrame
                blockAttributes.referenceFrame = blockFrame
                
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
        let offset: CGFloat
        if #available(iOS 11.0, *) {
            offset = collectionView!.contentOffset.y + collectionView!.adjustedContentInset.top
        } else {
            offset = collectionView!.contentOffset.y + collectionView!.contentInset.top
        }
        
        let rowAttributes = rowAttributesMap.filter({ $0.1.frame.intersects(rect) }).map({ $0.1 })
        let blockAttributes = blockAttributesMap.filter({ $0.1.frame.intersects(rect) }).map({ $0.1 })
        
        if !screen.isStretchyHeaderEnabled {
            return rowAttributes + blockAttributes
        }
        
        guard offset < 0 else {
            return rowAttributes + blockAttributes
        }
        
        let deltaY = fabs(offset)
        
        if let headerAttributes = rowAttributes.first(where: { $0.indexPath.section == 0 }) {
            var frame = headerAttributes.referenceFrame
            frame.size.height = max(0, frame.size.height + deltaY)
            frame.origin.y = frame.origin.y - deltaY
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

