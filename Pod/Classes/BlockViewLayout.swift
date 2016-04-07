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
                
                yOffset = yOffset + heightForItem(layout: block)
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
        
        if let fixedWidth = block.width?.forWidth(self.collectionView!.frame.width) {
            width = fixedWidth
            
            guard let horizontalAlignment = block.horizontalAlignment else { return CGRectZero }
            
            switch horizontalAlignment {
            case .Left:
                guard let leftOffset = block.leftOffset?.forWidth(collectionViewWidth) else { return CGRectZero }
                
                x = leftOffset
            case .Right:
                guard let rightOffset = block.rightOffset?.forWidth(collectionViewWidth) else { return CGRectZero }
                
                x = collectionViewWidth - width - rightOffset
            case .Center:
                guard let centerOffset = block.centerOffset?.forWidth(collectionViewWidth) else { return CGRectZero }
                
                x = ((collectionViewWidth - width) / 2) + centerOffset
            }
        } else {
            
            guard let leftOffset = block.leftOffset?.forWidth(collectionViewWidth),
                let rightOffset = block.rightOffset?.forWidth(collectionViewWidth) else { return CGRectZero }
            
            x = leftOffset
            width = collectionViewWidth - leftOffset - rightOffset
        }
        
        // Vertical Layout
        
        if let fixedHeight = block.height?.forWidth(collectionViewWidth) {
            height = fixedHeight
            
            switch block.verticalAlignment {
            case .Bottom?:
                guard let bottomOffset = block.bottomOffset?.forWidth(collectionViewWidth) else { return CGRectZero }
                
                y = yOffset + sectionHeight - height - bottomOffset
            case .Middle?:
                guard let middleOffset = block.middleOffset?.forWidth(collectionViewWidth) else { return CGRectZero }
                
                y = yOffset + ((sectionHeight - height) / 2) + middleOffset
            default:
                guard let topOffset = block.topOffset?.forWidth(collectionViewWidth) else { return CGRectZero }
                
                y = yOffset + topOffset
            }
        } else {
            
            guard let topOffset = block.topOffset?.forWidth(collectionViewWidth),
                let bottomOffset = block.bottomOffset?.forWidth(collectionViewWidth) else { return CGRectZero }
            
            y = yOffset + topOffset
            height = sectionHeight - topOffset - bottomOffset
        }
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    func heightForItem(layout block: Block) -> CGFloat {
        let collectionViewWidth = self.collectionView!.frame.width
        
        switch block.position! {
        case .Floating:
            return 0
        case .Stacked:
            guard let top = block.topOffset?.forWidth(collectionViewWidth),
                let height = block.height?.forWidth(collectionViewWidth),
                let bottom = block.bottomOffset?.forWidth(collectionViewWidth) else { return 0 }
            
            return top + height + bottom
        }
    }
    
    
    
}
