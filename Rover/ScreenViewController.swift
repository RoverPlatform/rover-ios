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
        
        self.collectionView!.backgroundView = backgroundView(backgroundConfiguration: screen, inFrame: collectionView!.frame)
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
                navTitleColor = self.navigationController?.navigationBar.titleTextAttributes![NSAttributedStringKey.foregroundColor] as? UIColor
                self.navigationController?.navigationBar.titleTextAttributes![NSAttributedStringKey.foregroundColor] = titleColor
            } else {
                self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: titleColor]
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
            
            if let image = imageBlock.image {
                if let scheme = image.url.scheme, scheme == "data" {
                    imageCell.imageView.rv_setImage(url: image.url, activityIndicatorStyle: .gray)
                } else {
                    let config = image.stretchConfiguration(forFrame: frame)
                    imageCell.imageView.rv_setImage(url: config.url, activityIndicatorStyle: .gray)
                }
            }
            
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
        
        cell.backgroundView = backgroundView(backgroundConfiguration: block, inFrame: frame)
        
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
    
    func backgroundView(backgroundConfiguration: BackgroundConfiguration?, inFrame frame: CGRect) -> UIImageView? {
        guard let backgroundConfiguration = backgroundConfiguration, let backgroundImage = backgroundConfiguration.backgroundImage else {
            return nil
        }
        
        var imageConfiguration: ImageConfiguration = (backgroundImage.url, 1)
        
        switch backgroundConfiguration.backgroundContentMode {
        case .Original:
            imageConfiguration = backgroundImage.originalConfiguration(forFrame: frame, scale: backgroundConfiguration.backgroundScale)
        case .Tile:
            imageConfiguration = backgroundImage.tileConfiguration(forFrame: frame, scale: backgroundConfiguration.backgroundScale)
        case .Stretch:
            imageConfiguration = backgroundImage.stretchConfiguration(forFrame: frame)
        case .Fill:
            imageConfiguration = backgroundImage.fillConfiguration(forFrame: frame)
        case .Fit:
            imageConfiguration = backgroundImage.fitConfiguration(forFrame: frame)
        }
        
        let backgroundView = UIImageView()
        
        AssetManager.sharedManager.fetchAsset(url: imageConfiguration.url) { data in
            guard let data = data, let image = UIImage(data: data, scale: imageConfiguration.scale) else {
                return
            }
            
            switch backgroundConfiguration.backgroundContentMode {
            case .Tile:
                backgroundView.backgroundColor = UIColor(patternImage: image)
            default:
                backgroundView.image = image
                backgroundView.contentMode = UIViewContentMode(imageContentMode: backgroundConfiguration.backgroundContentMode)
            }
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
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
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

fileprivate extension CGFloat {
    
    var paramValue: String {
        let rounded = self.rounded()
        let int = Int(rounded)
        return int.description
    }
}

protocol BackgroundConfiguration {
    
    var backgroundImage: Image? { get }
    
    var backgroundContentMode: ImageContentMode { get }
    
    var backgroundScale: CGFloat { get }
}

extension Block: BackgroundConfiguration { }

extension Screen: BackgroundConfiguration { }

fileprivate typealias ImageConfiguration = (url: URL, scale: CGFloat)

fileprivate extension Image {
    
    func stretchConfiguration(forFrame frame: CGRect) -> ImageConfiguration {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return (url, 1)
        }
        
        var queryItems = components.queryItems ?? [URLQueryItem]()
        
        let width = min(frame.width * UIScreen.main.scale, size.width)
        let height = min(frame.height * UIScreen.main.scale, size.height)
        
        queryItems.append(contentsOf: [
            URLQueryItem(name: "w", value: width.paramValue),
            URLQueryItem(name: "h", value: height.paramValue)
            ])
        
        components.queryItems = queryItems
        
        guard let optimizedURL = components.url else {
            return (url, 1)
        }
        
        return (optimizedURL, 1)
    }
    
    func fitConfiguration(forFrame frame: CGRect) -> ImageConfiguration {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return (url, 1)
        }
        
        var queryItems = components.queryItems ?? [URLQueryItem]()
        
        let width = frame.width * UIScreen.main.scale
        let height = frame.height * UIScreen.main.scale
        
        queryItems.append(contentsOf: [
            URLQueryItem(name: "fit", value: "max"),
            URLQueryItem(name: "w", value: width.paramValue),
            URLQueryItem(name: "h", value: height.paramValue)
            ])
        
        components.queryItems = queryItems
        
        guard let optimizedURL = components.url else {
            return (url, 1)
        }
        
        return (optimizedURL, 1)
    }
    
    func fillConfiguration(forFrame frame: CGRect) -> ImageConfiguration {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return (url, 1)
        }
        
        var queryItems = components.queryItems ?? [URLQueryItem]()

        let width = frame.width * UIScreen.main.scale
        let height = frame.height * UIScreen.main.scale
        
        queryItems.append(contentsOf: [
            URLQueryItem(name: "fit", value: "min"),
            URLQueryItem(name: "w", value: width.paramValue),
            URLQueryItem(name: "h", value: height.paramValue)
            ])
        
        components.queryItems = queryItems
        
        guard let optimizedURL = components.url else {
            return (url, 1)
        }
        
        return (optimizedURL, 1)
    }
    
    func originalConfiguration(forFrame frame: CGRect, scale: CGFloat) -> ImageConfiguration {
        let width = min(frame.width * scale, size.width)
        let height = min(frame.height * scale, size.height)
        let x = (size.width - width) / 2
        let y = (size.height - height) / 2
        let rect = CGRect(x: x, y: y, width: width, height: height)
        return croppedConfiguration(forRect: rect, scale: scale)
    }

    func tileConfiguration(forFrame frame: CGRect, scale: CGFloat) -> ImageConfiguration {
        let width = min(frame.width * scale, size.width)
        let height = min(frame.height * scale, size.height)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        return croppedConfiguration(forRect: rect, scale: scale)
    }
    
    func croppedConfiguration(forRect rect: CGRect, scale: CGFloat) -> ImageConfiguration {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return (url, 1)
        }
        
        var queryItems = components.queryItems ?? [URLQueryItem]()
        
        let value = [
            rect.origin.x.paramValue,
            rect.origin.y.paramValue,
            rect.width.paramValue,
            rect.height.paramValue
            ].joined(separator: ",")
        
        queryItems.append(URLQueryItem(name: "rect", value: value))
        
        var croppedScale = scale
        
        if UIScreen.main.scale < croppedScale {
            let width = rect.width / scale * UIScreen.main.scale
            let height = rect.height / scale * UIScreen.main.scale
            
            queryItems.append(contentsOf: [
                URLQueryItem(name: "w", value: width.paramValue),
                URLQueryItem(name: "h", value: height.paramValue)
                ])
            
            croppedScale = UIScreen.main.scale
        }
        
        components.queryItems = queryItems
        
        guard let croppedURL = components.url else {
            return (url, 1)
        }
        
        return (croppedURL, croppedScale)
    }
}
