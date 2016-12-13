//
//  RVScreenViewController.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

@objc public protocol ScreenViewControllerDelegate: class {
    @objc optional func screenViewController(_ viewController: ScreenViewController, handleOpenURL url: URL)
    @objc optional func screenViewController(_ viewController: ScreenViewController, handleOpenScreenWithIdentifier identifier: String)
    @objc optional func screenViewController(_ viewController: ScreenViewController, didPressBlock block: Block)
}

private let defaultBlockCellIdentifier = "defaultBlockCellIdentifier"
private let textBlockCellIdentifier = "textBlockCellIdentifier"
private let imageBlockCellIdentifier = "imageBlockCellIdentifier"
private let buttonBlockCellIdentifier = "buttonBlockCellIdentifier"
private let webBlockCellIdentifier = "webBlockCellIdentifier"

open class ScreenViewController: UICollectionViewController {
    
    var screen: Screen? {
        didSet {
            reloadScreen()
            collectionView?.reloadData()
        }
    }
    
    var activityIndicatorView: UIActivityIndicatorView?
    
    open weak var delegate: ScreenViewControllerDelegate?
    
    let layout = BlockViewLayout()
    
    public init() {
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
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.register(BlockViewCell.self, forCellWithReuseIdentifier: defaultBlockCellIdentifier)
        self.collectionView!.register(TextBlockViewCell.self, forCellWithReuseIdentifier: textBlockCellIdentifier)
        self.collectionView!.register(ImageBlockViewCell.self, forCellWithReuseIdentifier: imageBlockCellIdentifier)
        self.collectionView!.register(ButtonBlockViewCell.self, forCellWithReuseIdentifier: buttonBlockCellIdentifier)
        self.collectionView!.register(WebBlockViewCell.self, forCellWithReuseIdentifier: webBlockCellIdentifier)

    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadScreen()
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        revertNavigationBarStyles()
    }

    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    var leftNavBarItem: UIBarButtonItem?
    var rightNavBarItem: UIBarButtonItem?
    
    func reloadScreen() {
        self.title = screen?.title
        self.collectionView!.backgroundView = nil
        self.collectionView!.backgroundColor = screen?.backgroundColor ?? UIColor.white
        
        if !(screen?.useDefaultNavBarStyle ?? true) {
            applyNavigationBarStyle()
        }
        
        leftNavBarItem = navigationItem.leftBarButtonItem
        rightNavBarItem = navigationItem.rightBarButtonItem
        
        switch screen?.navBarButtons {
        case .Close?:
            navigationItem.leftBarButtonItem = nil
            navigationItem.setHidesBackButton(true, animated: true)
            navigationItem.rightBarButtonItem = rightNavBarItem
        case .Back?:
            navigationItem.rightBarButtonItem = nil
            navigationItem.leftBarButtonItem = leftNavBarItem
            navigationItem.setHidesBackButton(false, animated: true)
        case .None?:
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = nil
            navigationItem.setHidesBackButton(true, animated: true)
        default:
            navigationItem.leftBarButtonItem = leftNavBarItem
            navigationItem.rightBarButtonItem = rightNavBarItem
            navigationItem.setHidesBackButton(false, animated: true)
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
            self.navigationController?.navigationBar.barStyle = statusBarStyle == .lightContent ? .black : .default
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

    override open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return screen?.rows.count ?? 0
    }


    override open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return screen?.rows[section].blocks.count ?? 0
    }

    override open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: BlockViewCell
        let block = screen?.rows[indexPath.section].blocks[indexPath.row]
        
        let frame = layout.layoutAttributesForItem(at: indexPath)?.frame ?? CGRect.zero
        let maxCornerRadius = min(frame.height, frame.width) / 2
        
        switch block {
        case let textBlock as TextBlock:
            let textCell = collectionView.dequeueReusableCell(withReuseIdentifier: textBlockCellIdentifier, for: indexPath) as! TextBlockViewCell
        
            textCell.text = textBlock.attributedText
            textCell.textAlignment = textBlock.textAlignment
            textCell.textColor = textBlock.textColor
            //textCell.font = textBlock.font

            cell = textCell
        case let imageBlock as ImageBock:
            let imageCell = collectionView.dequeueReusableCell(withReuseIdentifier: imageBlockCellIdentifier, for: indexPath) as! ImageBlockViewCell
            
            imageCell.imageView.image = nil
            // TODO: cancel any requests or images from the reused cell
            
            let url = format(imageURL: imageBlock.image?.url, toSize: frame.size)
            imageCell.imageView.rv_setImage(url: url, activityIndicatorStyle: .gray)
            
            cell = imageCell
        case let buttonBlock as ButtonBlock:
            let buttonCell = collectionView.dequeueReusableCell(withReuseIdentifier: buttonBlockCellIdentifier, for: indexPath) as! ButtonBlockViewCell
            
            buttonBlock.appearences.forEach { (state, appearance) in
                buttonCell.setTitle(appearance.attributedTitle, forState: state.controlState)
                buttonCell.setTitleColor(appearance.titleColor, forState: state.controlState)
                buttonCell.setTitleAlignment(appearance.titleAlignment, forState: state.controlState)
                buttonCell.setTitleOffset(appearance.titleOffset, forState: state.controlState)
                buttonCell.setTitleFont(appearance.titleFont, forState: state.controlState)
                buttonCell.setBackgroundColor(appearance.backgroundColor, forState: state.controlState)
                buttonCell.setBorderColor(appearance.borderColor, forState: state.controlState)
                buttonCell.setBorderWidth(appearance.borderWidth, forState: state.controlState)
                if let cornerRadius = appearance.borderRadius {
                    buttonCell.setCornerRadius(min(cornerRadius, maxCornerRadius), forState: state.controlState)
                }
            }
            
            cell = buttonCell
        case let webBlock as WebBlock:
            let webCell = collectionView.dequeueReusableCell(withReuseIdentifier: webBlockCellIdentifier, for: indexPath) as! WebBlockViewCell
            
            webCell.url = webBlock.url
            webCell.scrollable = webBlock.scrollable
            
            cell = webCell
        default:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: defaultBlockCellIdentifier, for: indexPath) as! BlockViewCell
        }
        
        // BackgroundImage
        
        cell.backgroundView = backgroundView(forBlock: block, inRect: frame)
        
        // Appearance
        
        if !(cell is ButtonBlockViewCell) {
        	cell.backgroundColor = block?.backgroundColor
        	cell.layer.borderColor = block?.borderColor.cgColor
            cell.layer.borderWidth = block?.borderWidth ?? cell.layer.borderWidth
            cell.layer.cornerRadius = min(block?.borderRadius ?? cell.layer.cornerRadius, maxCornerRadius)
        }
        
        cell.layer.opacity = block?.opacity ?? cell.layer.opacity
        
        cell.inset = block?.inset ?? cell.inset
        cell.delegate = self

        
        if let clipPath = layout.clipPathForItemAtIndexPath(indexPath) {
            let maskLayer = CAShapeLayer()
            maskLayer.path = clipPath
            cell.layer.mask = maskLayer
        } else {
            cell.layer.mask = nil
        }
        
        return cell
    }
    
    func format(imageURL: URL?, toSize size: CGSize) -> URL? {
        guard let url = imageURL else {
            return nil
        }
        
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        
        var queryItems = components.queryItems ?? [URLQueryItem]()
        
        let width = (UIScreen.main.scale * size.width).rounded()
        let w = URLQueryItem(name: "w", value: Int(width).description)
        queryItems.append(w)
        
        let height = (UIScreen.main.scale * size.height).rounded()
        let h = URLQueryItem(name: "h", value: Int(height).description)
        queryItems.append(h)
        
        components.queryItems = queryItems
        return components.url
    }
    
    func backgroundView(forBlock block: Block?, inRect rect: CGRect) -> UIImageView? {
        guard let block = block, let backgroundImage = block.backgroundImage else {
            return nil
        }
        
        switch block.backgroundContentMode {
        case .Original:
            return croppedBackgroundView(forBlock: block, backgroundImage: backgroundImage, inRect: rect)
        default:
            return nil
        }
    }

    func croppedBackgroundView(forBlock block: Block, backgroundImage: Image, inRect rect: CGRect) -> UIImageView? {
        guard var components = URLComponents(url: backgroundImage.url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        var queryItems = components.queryItems ?? [URLQueryItem]()
        
        let width = min(rect.width * block.backgroundScale, backgroundImage.size.width)
        let height = min(rect.height * block.backgroundScale, backgroundImage.size.height)
        let x = (backgroundImage.size.width - width) / 2
        let y = (backgroundImage.size.height - height) / 2
        
        func floatParam(_ float: CGFloat) -> String {
            let r = float.rounded()
            let i = Int(r)
            return i.description
        }
        
        let value = [
            floatParam(x),
            floatParam(y),
            floatParam(width),
            floatParam(height)
        ].joined(separator: ",")
        
        let rect = URLQueryItem(name: "rect", value: value)
        queryItems.append(rect)
        
        var deviceScale = block.backgroundScale
        
        if UIScreen.main.scale < block.backgroundScale {
            let scaledWidth = floatParam(width / block.backgroundScale * UIScreen.main.scale)
            let w = URLQueryItem(name: "w", value: scaledWidth)
            queryItems.append(w)
            
            let scaledHeight = floatParam(height / block.backgroundScale * UIScreen.main.scale)
            let h = URLQueryItem(name: "h", value: scaledHeight)
            queryItems.append(h)
            
            deviceScale = UIScreen.main.scale
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            return nil
        }
        
        let backgroundView = UIImageView()
        
        AssetManager.sharedManager.fetchAsset(url: url) { data in
            guard let data = data, let image = UIImage(data: data, scale: deviceScale) else {
                return
            }

            backgroundView.image = image
            backgroundView.contentMode = UIViewContentMode(imageContentMode: .Original)
        }
        
        return backgroundView
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
    
    open override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        super.willRotate(to: toInterfaceOrientation, duration: duration)
        layout.invalidateLayout()
        collectionView?.reloadData()
    }

}

extension ScreenViewController : BlockViewCellDelegate {
    func blockViewCellDidPressButton(_ cell: BlockViewCell) {
        guard let indexPath = collectionView!.indexPath(for: cell),
            let block = screen?.rows[(indexPath as NSIndexPath).section].blocks[(indexPath as NSIndexPath).row],
            let action = block.action else { return }
        
        delegate?.screenViewController?(self, didPressBlock:block)
        
        switch action {
        case .deeplink(let url):
            UIApplication.shared.openURL(url)
        case .website(let url): // Legacy
            //guard let urlDelegate = delegate?.screenViewController?(self, handleOpenURL: url) else { return }

            UIApplication.shared.openURL(url)
        case .screen(let identifier):
            delegate?.screenViewController?(self, handleOpenScreenWithIdentifier: identifier)
        }
    }
}

extension ScreenViewController : BlockViewLayoutDataSource {
    func blockViewLayout(_ blockViewLayout: BlockViewLayout, heightForSection section: Int) -> CGFloat {
        return screen!.rows[section].instrinsicHeight(collectionView: collectionView!)
    }
    
    func blockViewLayout(_ blockViewLayout: BlockViewLayout, layoutForItemAtIndexPath indexPath: IndexPath) -> Block {
        return screen!.rows[(indexPath as NSIndexPath).section].blocks[(indexPath as NSIndexPath).row]
    }
}

extension Row {
    func instrinsicHeight(collectionView: UICollectionView) -> CGFloat {
        return height?.forParentValue(collectionView.frame.height) ?? blocks.reduce(0) { (height, block) -> CGFloat in
            return height + block.instrinsicHeight(collectionView: collectionView)
        }
    }
}

extension Block {
    func instrinsicHeight(collectionView: UICollectionView) -> CGFloat {
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
        case .disabled:
            return .disabled
        case .highlighted:
            return .highlighted
        case .selected:
            return .selected
        default:
            return UIControlState()
        }
    }
}

extension UIViewContentMode {
    init(imageContentMode: ImageContentMode) {
        switch imageContentMode {
        case .Fill:
            self = .scaleAspectFill
        case .Fit:
            self = .scaleAspectFit
        case .Stretch:
            self = .scaleToFill
        default:
            self = .center
        }
    }
}

extension UIImageView {
    func setBackgroundImage(url: URL, contentMode: ImageContentMode, scale: CGFloat) {
        AssetManager.sharedManager.fetchAsset(url: url) { (data) in
            guard let data = data, let image = UIImage(data: data, scale: scale) else { return }
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

