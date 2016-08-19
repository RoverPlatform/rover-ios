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
    optional func screenViewController(viewController: ScreenViewController, handleOpenScreenWithIdentifier identifier: String)
    optional func screenViewController(viewController: ScreenViewController, didPressBlock block: Block)
}

private let defaultBlockCellIdentifier = "defaultBlockCellIdentifier"
private let textBlockCellIdentifier = "textBlockCellIdentifier"
private let imageBlockCellIdentifier = "imageBlockCellIdentifier"
private let buttonBlockCellIdentifier = "buttonBlockCellIdentifier"
private let webBlockCellIdentifier = "webBlockCellIdentifier"

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
        self.collectionView!.registerClass(BlockViewCell.self, forCellWithReuseIdentifier: defaultBlockCellIdentifier)
        self.collectionView!.registerClass(TextBlockViewCell.self, forCellWithReuseIdentifier: textBlockCellIdentifier)
        self.collectionView!.registerClass(ImageBlockViewCell.self, forCellWithReuseIdentifier: imageBlockCellIdentifier)
        self.collectionView!.registerClass(ButtonBlockViewCell.self, forCellWithReuseIdentifier: buttonBlockCellIdentifier)
        self.collectionView!.registerClass(WebBlockViewCell.self, forCellWithReuseIdentifier: webBlockCellIdentifier)

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
    
    var leftNavBarItem: UIBarButtonItem?
    var rightNavBarItem: UIBarButtonItem?
    
    func reloadScreen() {
        self.title = screen?.title
        self.collectionView!.backgroundView = nil
        self.collectionView!.backgroundColor = screen?.backgroundColor ?? UIColor.whiteColor()
        
        if !(screen?.useDefaultNavBarStyle ?? true) {
            applyNavigationBarStyle()
        }
        
        leftNavBarItem = navigationItem.leftBarButtonItem
        rightNavBarItem = navigationItem.rightBarButtonItem
        
        switch screen?.navBarButtons {
        case .Close?:
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = rightNavBarItem
        case .Back?:
            navigationItem.rightBarButtonItem = nil
            navigationItem.leftBarButtonItem = leftNavBarItem
        case .None?:
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = nil
        default:
            navigationItem.leftBarButtonItem = leftNavBarItem
            navigationItem.rightBarButtonItem = rightNavBarItem
        }
        
        if let backgroundImage = screen?.backgroundImage {
            let imageView = UIImageView()
            imageView.setBackgroundImage(url: backgroundImage.url, contentMode: screen!.backgorundContentMode, scale: screen!.backgroundScale)
            self.collectionView!.backgroundView = imageView
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
        var cell: BlockViewCell
        let block = screen?.rows[indexPath.section].blocks[indexPath.row]
        
        switch block {
        case let textBlock as TextBlock:
            let textCell = collectionView.dequeueReusableCellWithReuseIdentifier(textBlockCellIdentifier, forIndexPath: indexPath) as! TextBlockViewCell
        
            textCell.text = textBlock.attributedText
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
                buttonCell.setTitle(appearance.attributedTitle, forState: state.controlState)
                buttonCell.setTitleColor(appearance.titleColor, forState: state.controlState)
                buttonCell.setTitleAlignment(appearance.titleAlignment, forState: state.controlState)
                buttonCell.setTitleOffset(appearance.titleOffset, forState: state.controlState)
                buttonCell.setTitleFont(appearance.titleFont, forState: state.controlState)
                buttonCell.setBackgroundColor(appearance.backgroundColor, forState: state.controlState)
                buttonCell.setBorderColor(appearance.borderColor, forState: state.controlState)
                buttonCell.setBorderWidth(appearance.borderWidth, forState: state.controlState)
                buttonCell.setCornerRadius(appearance.borderRadius, forState: state.controlState)
            }
            
            cell = buttonCell
        case let webBlock as WebBlock:
            let webCell = collectionView.dequeueReusableCellWithReuseIdentifier(webBlockCellIdentifier, forIndexPath: indexPath) as! WebBlockViewCell
            
            webCell.url = webBlock.url
            webCell.scrollable = webBlock.scrollable
            
            cell = webCell
        default:
            cell = collectionView.dequeueReusableCellWithReuseIdentifier(defaultBlockCellIdentifier, forIndexPath: indexPath) as! BlockViewCell
        }
        
        // BackgroundImage
        
        if let backgroundImage = block?.backgroundImage {
            var backgroundView = UIImageView()
            backgroundView.setBackgroundImage(url: backgroundImage.url, contentMode: block!.backgroundContentMode, scale: block!.backgroundScale)
            cell.backgroundView = backgroundView
        }
        
        // Appearance
        
        if !(cell is ButtonBlockViewCell) {
        	cell.backgroundColor = block?.backgroundColor
        	cell.layer.borderColor = block?.borderColor.CGColor
            cell.layer.borderWidth = block?.borderWidth ?? cell.layer.borderWidth
            cell.layer.cornerRadius = block?.borderRadius ?? cell.layer.cornerRadius
        }
        
        cell.layer.opacity = block?.opacity ?? cell.layer.opacity
        
        cell.inset = block?.inset ?? cell.inset
        cell.delegate = self
        
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

extension ScreenViewController : BlockViewCellDelegate {
    func blockViewCellDidPressButton(cell: BlockViewCell) {
        guard let indexPath = collectionView!.indexPathForCell(cell),
            block = screen?.rows[indexPath.section].blocks[indexPath.row],
            action = block.action else { return }
        
        delegate?.screenViewController?(self, didPressBlock:block)
        
        switch action {
        case .Deeplink(let url):
            UIApplication.sharedApplication().openURL(url)
        case .Website(let url): // Legacy
            guard let urlDelegate = delegate?.screenViewController?(self, handleOpenURL: url) else { return }

            UIApplication.sharedApplication().openURL(url)
        case .Screen(let identifier):
            delegate?.screenViewController?(self, handleOpenScreenWithIdentifier: identifier)
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

extension UIViewContentMode {
    init(imageContentMode: ImageContentMode) {
        switch imageContentMode {
        case .Fill:
            self = .ScaleAspectFill
        case .Fit:
            self = .ScaleAspectFit
        case .Stretch:
            self = .ScaleToFill
        default:
            self = .Center
        }
    }
}

extension UIImageView {
    func setBackgroundImage(url url: NSURL, contentMode: ImageContentMode, scale: CGFloat) {
        AssetManager.sharedManager.fetchAsset(url: url) { (data) in
            guard let data = data, image = UIImage(data: data, scale: scale) else { return }
            switch contentMode {
            case .Tile:
                self.backgroundColor = UIColor(patternImage: image)
            default:
                self.image = image
                self.contentMode = UIViewContentMode(imageContentMode: contentMode)
            }
        }
    }
}

