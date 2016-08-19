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
                attributes.zIndex = (numItems - item)
                
                cellAttributes[indexPath] = attributes
                
                if stacked {
                    yOffset = yOffset + fullHeightForItem(layout: block, sectionHeight: sectionHeight)
                }
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
    func forParentValue(parentValue: CGFloat) -> CGFloat {
        switch self {
        case .Percentage(let value):
            return CGFloat(value) * parentValue / 100.0
        case .Points(let value):
            return CGFloat(value)
        }
    }
}

// MARK: Block Size

extension Block {
    func heightInCollectionView(collectionView: UICollectionView, sectionHeight: CGFloat) -> CGFloat {
        
        if let height = height?.forParentValue(sectionHeight) {
            return height
        } else if let imageBock = self as? ImageBock, aspectRatio = imageBock.image?.aspectRatio where aspectRatio != 0 {
            let width = widthInCollectionView(collectionView)
            return width / aspectRatio
        } else if let textBlock = self as? TextBlock, string = textBlock.text as? NSString {
            let width = widthInCollectionView(collectionView) - self.inset.left - self.inset.right
            return string.boundingRectWithSize(CGSize(width: width, height: CGFloat.max), options: [.UsesLineFragmentOrigin, .UsesFontLeading], attributes: [NSFontAttributeName: textBlock.font], context: nil).height
        }
        
        return 0
    }
    // TODO: MORE BUGS HERE
    
    func widthInCollectionView(collectionView: UICollectionView) -> CGFloat {
        if alignment.horizontal == .Fill {
            let left = offset.left.forParentValue(collectionView.frame.width)
            let right = offset.right.forParentValue(collectionView.frame.width)
            return collectionView.frame.width - left - right
        }

        return self.width?.forParentValue(collectionView.frame.width) ?? 0
    }
}
