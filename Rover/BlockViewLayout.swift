//
//  BlockViewLayout.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

protocol BlockViewLayoutDataSource: class {
    func blockViewLayout(_ blockViewLayout: BlockViewLayout, heightForSection section: Int) -> CGFloat
    func blockViewLayout(_ blockViewLayout: BlockViewLayout, layoutForItemAtIndexPath indexPath: IndexPath) -> Block // TODO: Change to layout model
}

class BlockViewLayout: UICollectionViewLayout {
    
    weak var dataSource: BlockViewLayoutDataSource?

    fileprivate var cellAttributes = [IndexPath : UICollectionViewLayoutAttributes]()
    fileprivate var height: CGFloat = 0
    fileprivate var cellClipPaths = [IndexPath: CGPath]()
    
    override func prepare() {
        
        cellAttributes = [:]
        height = 0
        cellClipPaths = [:]
        
        let numSections = self.collectionView!.numberOfSections
        
        for section in 0..<numSections {
            
            let sectionHeight = self.dataSource!.blockViewLayout(self, heightForSection: section)
            let numItems = self.collectionView!.numberOfItems(inSection: section)
            var yOffset = height
            
            for item in 0..<numItems {
                
                let indexPath = IndexPath(row: item, section: section)
                let block = self.dataSource!.blockViewLayout(self, layoutForItemAtIndexPath: indexPath)
                let stacked = block.position == .Stacked
                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                
                attributes.frame = frameForItem(layout: block, yOffset: stacked ? yOffset : height, sectionHeight: sectionHeight)
                attributes.zIndex = (numItems - item)
                
                cellAttributes[indexPath] = attributes
                
                if attributes.frame.origin.y + attributes.frame.size.height > height + sectionHeight ||
                    attributes.frame.origin.y < height {
                    let clippedY = max(0, height - attributes.frame.origin.y)
                    let clippedHeight = min(height + sectionHeight - attributes.frame.origin.y, attributes.frame.height) - clippedY
                    cellClipPaths[indexPath] = CGPath(rect: CGRect(origin: CGPoint(x: 0, y:clippedY), size: CGSize(width: attributes.frame.width, height: clippedHeight)), transform: nil)
                }
                
                if stacked {
                    yOffset = yOffset + fullHeightForItem(layout: block, sectionHeight: sectionHeight)
                }
            }
         
            height = height + sectionHeight
        }
    }
    
    override var collectionViewContentSize : CGSize {
        return CGSize(width: self.collectionView!.frame.size.width, height: height)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        
        var attributesArray = [UICollectionViewLayoutAttributes]()
        
        for (_, attributes) in cellAttributes {
            if rect.intersects(attributes.frame) {
                attributesArray.append(attributes)
            }
        }
        
        return attributesArray
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cellAttributes[indexPath]
    }
    
    func clipPathForItemAtIndexPath(_ indexPath: IndexPath) -> CGPath? {
        return cellClipPaths[indexPath]
    }
    
    // MARK: Helpers
    
    
    func frameForItem(layout block: Block, yOffset: CGFloat, sectionHeight: CGFloat) -> CGRect {
        let collectionViewWidth = self.collectionView!.frame.width
        
        var x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
        
        // Horizontal Layout
        
        switch block.alignment.horizontal {
        case .Fill:
            let leftOffset = block.offset.left.forParentValue(collectionViewWidth)
            let rightOffset = block.offset.right.forParentValue(collectionViewWidth)
            
            width = collectionViewWidth - leftOffset - rightOffset
            x = leftOffset
        case .Left:
            let leftOffset = block.offset.left.forParentValue(collectionViewWidth)
            
            width = block.widthInCollectionView(collectionView!)
            x = leftOffset
        case .Right:
            let rightOffset = block.offset.right.forParentValue(collectionViewWidth)
            
            width = block.widthInCollectionView(collectionView!)
            x = collectionViewWidth - width - rightOffset
        case .Center:
            let centerOffset = block.offset.center.forParentValue(collectionViewWidth)
            
            width = block.widthInCollectionView(collectionView!)
            x = ((collectionViewWidth - width) / 2) + centerOffset
        }
        
        // Vertical Layout
        
        switch block.alignment.vertical {
        case .Fill:
            let topOffset = block.offset.top.forParentValue(sectionHeight)
            let bottomOffset = block.offset.bottom.forParentValue(sectionHeight)
            
            height = sectionHeight - topOffset - bottomOffset
            y = yOffset + topOffset
        case .Top:
            let topOffset = block.offset.top.forParentValue(sectionHeight)
            
            y = yOffset + topOffset
            height = block.heightInCollectionView(collectionView!, sectionHeight: sectionHeight)
        case .Bottom:
            let bottomOffset = block.offset.bottom.forParentValue(sectionHeight)
            
            height = block.heightInCollectionView(collectionView!, sectionHeight: sectionHeight)
            y = yOffset + sectionHeight - height - bottomOffset
        case .Middle:
            let middleOffset = block.offset.middle.forParentValue(sectionHeight)
            
            height = block.heightInCollectionView(collectionView!, sectionHeight: sectionHeight)
            y = yOffset + ((sectionHeight - height) / 2.0) + middleOffset
        }
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    func fullHeightForItem(layout block: Block, sectionHeight: CGFloat) -> CGFloat {
        switch block.position {
        case .Floating:
            return 0
        case .Stacked:
            let top = block.offset.top.forParentValue(sectionHeight)
            let height = block.heightInCollectionView(self.collectionView!, sectionHeight: sectionHeight)
            let bottom = block.offset.bottom.forParentValue(sectionHeight)
            
            return top + height + bottom
        }
    }
}

extension Unit {
    func forParentValue(_ parentValue: CGFloat) -> CGFloat {
        switch self {
        case .percentage(let value):
            return CGFloat(value) * parentValue / 100.0
        case .points(let value):
            return CGFloat(value)
        }
    }
}

// MARK: Block Size

extension Block {
    func heightInCollectionView(_ collectionView: UICollectionView, sectionHeight: CGFloat) -> CGFloat {
        
        if let height = height?.forParentValue(sectionHeight) {
            return height
        } else if let imageBock = self as? ImageBock, let aspectRatio = imageBock.image?.aspectRatio , aspectRatio != 0 {
            let width = widthInCollectionView(collectionView)
            return width / aspectRatio
        } else if let textBlock = self as? TextBlock, let attributedString = textBlock.attributedText {
            let width = widthInCollectionView(collectionView) - self.inset.left - self.inset.right
            return attributedString.boundingRect(with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height + inset.top + inset.bottom
        }
        
        return 0
    }
    // TODO: MORE BUGS HERE
    
    func widthInCollectionView(_ collectionView: UICollectionView) -> CGFloat {
        if alignment.horizontal == .Fill {
            let left = offset.left.forParentValue(collectionView.frame.width)
            let right = offset.right.forParentValue(collectionView.frame.width)
            return collectionView.frame.width - left - right
        }

        return self.width?.forParentValue(collectionView.frame.width) ?? 0
    }
}
