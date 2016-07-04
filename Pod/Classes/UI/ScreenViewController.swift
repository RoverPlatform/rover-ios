//
//  RVScreenViewController.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

@objc public protocol ScreenViewControllerDelegate: class {
    optional func screenViewController(viewController: ScreenViewController, handleOpenURL url: NSURL)
}

private let textBlockCellIdentifier = "textBlockCellIdentifier"
private let imageBlockCellIdentifier = "imageBlockCellIdentifier"
private let buttonBlockCellIdentifier = "buttonBlockCellIdentifier"

public class ScreenViewController: UICollectionViewController {
    
    var screen: Screen? {
        didSet {
            reloadScreen()
            collectionView?.reloadData()
        }
    }
    
    var activityIndicatorView: UIActivityIndicatorView?
    
    public weak var delegate: ScreenViewControllerDelegate?
    
    public init() {
        let layout = BlockViewLayout()
        super.init(collectionViewLayout: layout)
        layout.dataSource = self
    }
    
    public convenience init(screen: Screen) {
        self.init()
        self.screen = screen
        //reloadScreen()
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
        
        //if let navBarColor = screen?.navBarColor {

        //}
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        reloadScreen()
    }
    
    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        revertNavigationBarStyles()
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func reloadScreen() {
        self.title = screen?.title
        self.collectionView!.backgroundColor = screen?.backgroundColor
        
        if !(screen?.useDefaultNavBarStyle ?? true) {
            applyNavigationBarStyle()
        }
    }
    
    var navBarStyle: UIBarStyle?
    var navBarTintColor: UIColor?
    var navTintColor: UIColor?
    var navTitleColor: UIColor?
    
    func applyNavigationBarStyle() {
        if let navBarColor = screen?.navBarColor {
            navBarTintColor = self.navigationController?.navigationBar.barTintColor
            self.navigationController?.navigationBar.barTintColor = navBarColor
        }
        if let navItemColor = screen?.navItemColor {
            navTintColor = self.navigationController?.navigationBar.tintColor
            self.navigationController?.navigationBar.tintColor = navItemColor
        }
        if let titleColor = screen?.titleColor {
            if self.navigationController?.navigationBar.titleTextAttributes != nil {
                navTitleColor = self.navigationController?.navigationBar.titleTextAttributes![NSForegroundColorAttributeName] as? UIColor
                self.navigationController?.navigationBar.titleTextAttributes![NSForegroundColorAttributeName] = titleColor
            } else {
                self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: titleColor]
            }
        }
        if let statusBarStyle = screen?.statusBarStyle {
            navBarStyle = self.navigationController?.navigationBar.barStyle
            self.navigationController?.navigationBar.barStyle = statusBarStyle == .LightContent ? .Black : .Default
        }
    }
    
    func revertNavigationBarStyles() {
        if let navBarStyle = navBarStyle {
            self.navigationController?.navigationBar.barStyle = navBarStyle
        }
        self.navigationController?.navigationBar.barTintColor = navBarTintColor
        self.navigationController?.navigationBar.tintColor = navTintColor
        self.navigationController?.navigationBar.titleTextAttributes = [:]
    }

    // MARK: UICollectionViewDataSource

    override public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return screen?.rows.count ?? 0
    }


    override public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return screen?.rows[section].blocks.count ?? 0
    }

    override public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var cell: UICollectionViewCell
        let block = screen?.rows[indexPath.section].blocks[indexPath.row]
        
        switch block {
        case let textBlock as TextBlock:
            let textCell = collectionView.dequeueReusableCellWithReuseIdentifier(textBlockCellIdentifier, forIndexPath: indexPath) as! TextBlockViewCell
        
            textCell.text = textBlock.text
            textCell.textAlignment = textBlock.textAlignment
            textCell.textColor = textBlock.textColor
            textCell.font = textBlock.font

            cell = textCell
        case let imageBlock as ImageBock:
            let imageCell = collectionView.dequeueReusableCellWithReuseIdentifier(imageBlockCellIdentifier, forIndexPath: indexPath) as! ImageBlockViewCell
            
            imageCell.imageView.rv_setImage(url: imageBlock.image?.url, activityIndicatorStyle: .Gray)
            
            cell = imageCell
        case let buttonBlock as ButtonBlock:
            let buttonCell = collectionView.dequeueReusableCellWithReuseIdentifier(buttonBlockCellIdentifier, forIndexPath: indexPath) as! ButtonBlockViewCell
            
            buttonBlock.appearences.forEach { (state, appearance) in
                buttonCell.setTitle(appearance.title, forState: state.controlState)
                buttonCell.setTitleColor(appearance.titleColor, forState: state.controlState)
                buttonCell.setTitleAlignment(appearance.titleAlignment, forState: state.controlState)
                buttonCell.setTitleOffset(appearance.titleOffset, forState: state.controlState)
                buttonCell.setTitleFont(appearance.titleFont, forState: state.controlState)
                buttonCell.setBackgroundColor(appearance.backgroundColor, forState: state.controlState)
                buttonCell.setBorderColor(appearance.borderColor, forState: state.controlState)
                buttonCell.setBorderWidth(appearance.borderWidth, forState: state.controlState)
                buttonCell.setCornerRadius(appearance.borderRadius, forState: state.controlState)
            }
            
            buttonCell.delegate = self
            
            cell = buttonCell
        default:
            fatalError("Unknown block type")
        }
        
        if !(cell is ButtonBlockViewCell) {
        	cell.backgroundColor = block?.backgroundColor
        	cell.layer.borderColor = block?.borderColor.CGColor
            cell.layer.borderWidth = block?.borderWidth ?? cell.layer.borderWidth
            cell.layer.cornerRadius = block?.borderRadius ?? cell.layer.cornerRadius
        }
        
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
    
    public func showActivityIndicator() {
        let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        view.addSubview(activityIndicatorView)
        view.addConstraints([
            NSLayoutConstraint(item: activityIndicatorView, attribute: .CenterX, relatedBy: .Equal, toItem: view, attribute: .CenterX, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: activityIndicatorView, attribute: .CenterY, relatedBy: .Equal, toItem: view, attribute: .CenterY, multiplier: 1, constant: 0)
            ])
        activityIndicatorView.startAnimating()
        self.activityIndicatorView = activityIndicatorView
    }
    
    public func hideActivityIndicator() {
        activityIndicatorView?.stopAnimating()
        activityIndicatorView?.removeFromSuperview()
    }

}

extension ScreenViewController : ButtonBlockViewCellDelegate {
    func buttonBlockViewCellDidPressButton(cell: ButtonBlockViewCell) {
        guard let indexPath = collectionView!.indexPathForCell(cell),
            buttonBlock = screen?.rows[indexPath.section].blocks[indexPath.row] as? ButtonBlock,
            action = buttonBlock.action else { return }
        
        switch action {
        case .Deeplink(let url):
            UIApplication.sharedApplication().openURL(url)
        case .Website(let url):
            if let urlDelegate = delegate?.screenViewController {
                urlDelegate(self, handleOpenURL: url)
            } else {
                UIApplication.sharedApplication().openURL(url)
            }
        }
    }
}

extension ScreenViewController : BlockViewLayoutDataSource {
    func blockViewLayout(blockViewLayout: BlockViewLayout, heightForSection section: Int) -> CGFloat {
        return screen!.rows[section].instrinsicHeight(collectionView: collectionView!)
    }
    
    func blockViewLayout(blockViewLayout: BlockViewLayout, layoutForItemAtIndexPath indexPath: NSIndexPath) -> Block {
        return screen!.rows[indexPath.section].blocks[indexPath.row]
    }
}

extension Row {
    func instrinsicHeight(collectionView collectionView: UICollectionView) -> CGFloat {
        return height?.forParentValue(collectionView.frame.height) ?? blocks.reduce(0) { (height, block) -> CGFloat in
            return height + block.instrinsicHeight(collectionView: collectionView)
        }
    }
}

extension Block {
    func instrinsicHeight(collectionView collectionView: UICollectionView) -> CGFloat {
        if position == .Stacked {
            let height = heightInCollectionView(collectionView, sectionHeight: 0)
            return offset.top.forParentValue(0) + height + offset.bottom.forParentValue(0)
        } else {
            return 0
        }
    }
}

extension ButtonBlock.State {
    var controlState: UIControlState {
        switch self {
        case .Disabled:
            return .Disabled
        case .Highlighted:
            return .Highlighted
        case .Selected:
            return .Selected
        default:
            return .Normal
        }
    }
}


