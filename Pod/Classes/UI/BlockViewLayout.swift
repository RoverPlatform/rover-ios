//
//  BlockViewLayout.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

protocol BlockViewLayoutDataSource: class {
    func blockViewLayout(blockViewLayout: BlockViewLayout, heightForSection section: Int) -> CGFloat
    func blockViewLayout(blockViewLayout: BlockViewLayout, layoutForItemAtIndexPath indexPath: NSIndexPath) -> Block // TODO: Change to layout model
}

class BlockViewLayout: UICollectionViewLayout {
    
    weak var dataSource: BlockViewLayoutDataSource?

    private var cellAttributes = [NSIndexPath : UICollectionViewLayoutAttributes]()
    private var height: CGFloat = 0
    
    override func prepareLayout() {
        
        cellAttributes = [:]
        height = 0
        
        let numSections = self.collectionView!.numberOfSections()
        
        for section in 0..<numSections {
            
            let sectionHeight = self.dataSource!.blockViewLayout(self, heightForSection: section)
            let numItems = self.collectionView!.numberOfItemsInSection(section)
            var yOffset = height
            
            for item in 0..<numItems {
                
                let indexPath = NSIndexPath(forRow: item, inSection: section)
                let block = self.dataSource!.blockViewLayout(self, layoutForItemAtIndexPath: indexPath)
                let stacked = block.position == .Stacked
                let attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
                
                attributes.frame = frameForItem(layout: block, yOffset: stacked ? yOffset : height, sectionHeight: sectionHeight)
                attributes.zIndex = (section + 1) * (item + 1)
                
                cellAttributes[indexPath] = attributes
                
                // if stacked {
                yOffset = yOffset + heightForItem(layout: block)
                // }
            }
         
            height = height + sectionHeight
        }
    }
    
    override func collectionViewContentSize() -> CGSize {
        return CGSize(width: self.collectionView!.frame.size.width, height: height)
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        
        var attributesArray = [UICollectionViewLayoutAttributes]()
        
        for (_, attributes) in cellAttributes {
            if CGRectIntersectsRect(rect, attributes.frame) {
                attributesArray.append(attributes)
            }
        }
        
        return attributesArray
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        return cellAttributes[indexPath]
    }
    
    // MARK: Helpers
    
    
    func frameForItem(layout block: Block, yOffset: CGFloat, sectionHeight: CGFloat) -> CGRect {
        let collectionViewWidth = self.collectionView!.frame.width
        
        var x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
        
        // Horizontal Layout
        
        switch block.alignment.horizontal {
        case .Fill:
            let leftOffset = block.offset.left.forWidth(collectionViewWidth)
            let rightOffset = block.offset.right.forWidth(collectionViewWidth)
            
            width = collectionViewWidth - leftOffset - rightOffset
            x = leftOffset
        case .Left:
            let leftOffset = block.offset.left.forWidth(collectionViewWidth)
            
            width = block.widthInCollectionView(width: collectionViewWidth)
            x = leftOffset
        case .Right:
            let rightOffset = block.offset.right.forWidth(collectionViewWidth)
            
            width = block.widthInCollectionView(width: collectionViewWidth)
            x = collectionViewWidth - width - rightOffset
        case .Center:
            let centerOffset = block.offset.center.forWidth(collectionViewWidth)
            
            width = block.widthInCollectionView(width: collectionViewWidth)
            x = ((collectionViewWidth - width) / 2) + centerOffset
        }
        
        // Vertical Layout
        
        switch block.alignment.vertical {
        case .Fill:
            let topOffset = block.offset.top.forWidth(collectionViewWidth)
            let bottomOffset = block.offset.bottom.forWidth(collectionViewWidth)
            
            height = sectionHeight - topOffset - bottomOffset
            y = yOffset + topOffset
        case .Top:
            let topOffset = block.offset.top.forWidth(collectionViewWidth)
            
            y = yOffset + topOffset
            height = block.heightInCollectionView(width: collectionViewWidth)
        case .Bottom:
            let bottomOffset = block.offset.bottom.forWidth(collectionViewWidth)
            
            height = block.heightInCollectionView(width: collectionViewWidth)
            y = yOffset + sectionHeight - height - bottomOffset
        case .Middle:
            let middleOffset = block.offset.middle.forWidth(collectionViewWidth)
            
            height = block.heightInCollectionView(width: collectionViewWidth)
            y = yOffset + ((sectionHeight - height) / 2) + middleOffset
        }
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    func heightForItem(layout block: Block) -> CGFloat {
        let collectionViewWidth = self.collectionView!.frame.width
        
        switch block.position {
        case .Floating:
            return 0
        case .Stacked:
            let top = block.offset.top.forWidth(collectionViewWidth)
            let height = block.heightInCollectionView(width: collectionViewWidth)
            let bottom = block.offset.bottom.forWidth(collectionViewWidth)
            
            return top + height + bottom
        }
    }
}

extension Unit {
    func forWidth(width: CGFloat) -> CGFloat {
        switch self {
        case .Percentage(let value):
            return CGFloat(value) * width
        case .Points(let value):
            return CGFloat(value)
        }
    }
}

// MARK: Block Size

extension Block {
    func heightInCollectionView(width width: CGFloat) -> CGFloat {
        
        if let height = height?.forWidth(width) {
            return height
        } else if let imageBock = self as? ImageBock, aspectRatio = imageBock.image?.aspectRatio {
            return width / aspectRatio
        } else if let textBlock = self as? TextBlock, string = textBlock.text as? NSString {
            return string.boundingRectWithSize(CGSize(width: width, height: CGFloat.max), options: [.UsesLineFragmentOrigin, .UsesFontLeading], attributes: [NSFontAttributeName: textBlock.font], context: nil).height
        }
        
        return 0
    }
    
    func widthInCollectionView(width width: CGFloat) -> CGFloat {
        return self.width?.forWidth(width) ?? 0
    }
}
