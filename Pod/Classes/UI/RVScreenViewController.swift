//
//  RVScreenViewController.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

private let textBlockCellIdentifier = "textBlockCellIdentifier"
private let imageBlockCellIdentifier = "imageBlockCellIdentifier"
private let buttonBlockCellIdentifier = "buttonBlockCellIdentifier"

public class RVScreenViewController: UICollectionViewController {
    
    let screen: Screen
    
    required public init(screen: Screen) {
        self.screen = screen
        
        let layout = BlockViewLayout()
        
        super.init(collectionViewLayout: layout)
        
        layout.dataSource = self
        self.title = screen.title
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented. You must use init(screen:).")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.registerClass(TextBlockViewCell.self, forCellWithReuseIdentifier: textBlockCellIdentifier)
        self.collectionView!.registerClass(ImageBlockViewCell.self, forCellWithReuseIdentifier: imageBlockCellIdentifier)
        self.collectionView!.registerClass(ButtonBlockViewCell.self, forCellWithReuseIdentifier: buttonBlockCellIdentifier)

        // Do any additional setup after loading the view.
        self.collectionView!.backgroundColor = UIColor.whiteColor()
    }

    override public func didReceiveMemoryWarning() {
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

    override public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return screen.rows.count
    }


    override public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return screen.rows[section].blocks.count
    }

    override public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var cell: UICollectionViewCell
        let block = screen.rows[indexPath.section].blocks[indexPath.row]
        
        switch block {
        case let textBlock as TextBlock:
            let textCell = collectionView.dequeueReusableCellWithReuseIdentifier(textBlockCellIdentifier, forIndexPath: indexPath) as! TextBlockViewCell
        
            textCell.textLabel.text = textBlock.text

            cell = textCell
        case let imageBlock as ImageBock:
            let imageCell = collectionView.dequeueReusableCellWithReuseIdentifier(imageBlockCellIdentifier, forIndexPath: indexPath) as! ImageBlockViewCell
            
            cell = imageCell
        case let buttonBlock as ButtonBlock:
            let buttonCell = collectionView.dequeueReusableCellWithReuseIdentifier(buttonBlockCellIdentifier, forIndexPath: indexPath) as! ButtonBlockViewCell
            
            buttonCell.titleLabel.text = buttonBlock.title
            buttonCell.titleLabel.textColor = buttonBlock.titleColor
            
            cell = buttonCell
        default:
            fatalError("Unknown block type")
        }
        
        cell.backgroundColor = block.backgroundColor
        cell.layer.borderColor = block.borderColor?.CGColor
        cell.layer.borderWidth = block.borderWidth ?? 0
        cell.layer.cornerRadius = block.borderRadius ?? 0
    
        return cell
    }

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override public func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool {
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
        return screen.rows[section].instrinsicHeight(width: collectionView!.frame.width)
    }
    
    func blockViewLayout(blockViewLayout: BlockViewLayout, layoutForItemAtIndexPath indexPath: NSIndexPath) -> Block {
        return screen.rows[indexPath.section].blocks[indexPath.row]
    }
}

extension Row {
    func instrinsicHeight(width width: CGFloat) -> CGFloat {
        return height?.forWidth(width) ?? blocks.reduce(0) { (height, block) -> CGFloat in
            return height + block.instrinsicHeight(width: width)
        }
    }
}

extension Block {
    func instrinsicHeight(width width: CGFloat) -> CGFloat {
        if position == .Stacked {
            guard let top = self.offset?.top?.forWidth(width),
                let blockHeight = self.height?.forWidth(width),
                let bottom = self.offset?.bottom?.forWidth(width) else { return 0 }
            
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

