//
//  RVScreenViewController.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

private let reuseIdentifier = "BlockCell"

class RVScreenViewController: UICollectionViewController {

    var rows = [Row]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
        
        let viewLayout = BlockViewLayout()
        viewLayout.dataSource = self

        self.collectionView!.collectionViewLayout = viewLayout
        
        // TEMP BEGIN
        
        let autoWidthBlock = Block()
        autoWidthBlock.position = .Stacked
        autoWidthBlock.height = .Points(100)
        autoWidthBlock.leftOffset = .Points(40)
        autoWidthBlock.rightOffset = .Points(40)
        autoWidthBlock.bottomOffset = .Points(20)
        autoWidthBlock.topOffset = .Points(20)
        
        let leftAlignedBlock = Block()
        leftAlignedBlock.position = .Stacked
        leftAlignedBlock.height = .Points(60)
        leftAlignedBlock.width = .Points(100)
        leftAlignedBlock.horizontalAlignment = .Left
        leftAlignedBlock.topOffset = .Points(10)
        leftAlignedBlock.bottomOffset = .Points(10)
        leftAlignedBlock.leftOffset = .Points(10)
        leftAlignedBlock.rightOffset = .Points(10)
        
        let rightAlignedBlock = Block()
        rightAlignedBlock.position = .Stacked
        rightAlignedBlock.height = .Points(60)
        rightAlignedBlock.width = .Points(100)
        rightAlignedBlock.horizontalAlignment = .Right
        rightAlignedBlock.topOffset = .Points(10)
        rightAlignedBlock.bottomOffset = .Points(10)
        rightAlignedBlock.leftOffset = .Points(10)
        rightAlignedBlock.rightOffset = .Points(10)
        
        let floatingBlock = Block()
        floatingBlock.position = .Floating
        floatingBlock.height = .Points(50)
        floatingBlock.width = .Points(50)
        floatingBlock.horizontalAlignment = .Left
        floatingBlock.bottomOffset = .Points(10)
        floatingBlock.verticalAlignment = .Bottom
        floatingBlock.leftOffset = .Points(10)
        floatingBlock.rightOffset = .Points(10)
        
        let row = Row()
        row.blocks = [autoWidthBlock, leftAlignedBlock, rightAlignedBlock, floatingBlock]
        
        rows = [row]
        
        collectionView?.reloadData()
        
        // TEMP END
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return rows.count
    }


    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return rows[section].blocks?.count ?? 0
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath)
    
        cell.backgroundColor = UIColor.grayColor()
    
        return cell
    }

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(collectionView: UICollectionView, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, canPerformAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, performAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
    
    }
    */

}

extension RVScreenViewController : BlockViewLayoutDataSource {
    
    func blockViewLayout(blockViewLayout: BlockViewLayout, heightForSection section: Int) -> CGFloat {
        return rows[section].instrinsicHeight(width: collectionView!.frame.width)
    }
    
    func blockViewLayout(blockViewLayout: BlockViewLayout, layoutForItemAtIndexPath indexPath: NSIndexPath) -> Block {
        return rows[indexPath.section].blocks![indexPath.row]
    }
    
}

extension Row {
    func instrinsicHeight(width width: CGFloat) -> CGFloat {
        return height?.forWidth(width) ?? blocks!.reduce(0) { (height, block) -> CGFloat in
            return height + block.instrinsicHeight(width: width)
        }
    }
}

extension Block {
    func instrinsicHeight(width width: CGFloat) -> CGFloat {
        if position == .Stacked {
            guard let top = self.topOffset?.forWidth(width),
                let blockHeight = self.height?.forWidth(width),
                let bottom = self.bottomOffset?.forWidth(width) else { return 0 }
            
            return top + blockHeight + bottom
        } else {
            return 0
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

