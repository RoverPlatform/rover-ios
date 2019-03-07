//
//  ScreenViewController.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

// ScreenViewController may deserve a refactor: https://github.com/RoverPlatform/rover-ios/issues/406
// swiftlint:disable type_body_length
/// ScreenViewController displays a screen within a Rover experience.
open class ScreenViewController: UICollectionViewController, UICollectionViewDataSourcePrefetching {
    static var fetchImageTaskKey: Void?
    
    public let experience: Experience
    public let screen: Screen
    
    public let dispatcher: Dispatcher
    public let eventQueue: EventQueue
    public let imageStore: ImageStore
    public let sessionController: SessionController
    
    public typealias ViewControllerProvider = (Experience, Screen) -> UIViewController?
    public let viewControllerProvider: ViewControllerProvider
    
    public typealias ActionProvider = (URL) -> Action?
    public let presentWebsiteActionProvider: ActionProvider
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        switch screen.statusBar.style {
        case .dark:
            return .default
        case .light:
            return .lightContent
        }
    }
    
    public init(collectionViewLayout: UICollectionViewLayout, experience: Experience, screen: Screen, dispatcher: Dispatcher, eventQueue: EventQueue, imageStore: ImageStore, sessionController: SessionController, viewControllerProvider: @escaping ViewControllerProvider, presentWebsiteActionProvider: @escaping ActionProvider) {
        self.experience = experience
        self.screen = screen
        self.dispatcher = dispatcher
        self.eventQueue = eventQueue
        self.imageStore = imageStore
        self.sessionController = sessionController
        self.viewControllerProvider = viewControllerProvider
        self.presentWebsiteActionProvider = presentWebsiteActionProvider
        
        super.init(collectionViewLayout: collectionViewLayout)
        collectionView?.prefetchDataSource = self
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.backgroundView = UIImageView()
        
        configureTitle()
        configureNavigationItem()
        configureBackgroundColor()
        configureBackgroundImage()
        
        registerReusableViews()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNavigationBar()
    }
    
    lazy var sessionIdentifier: String = {
        var identifier = "experience-\(experience.id.rawValue)-screen-\(screen.id.rawValue)"
        
        if let campaignID = experience.campaignID {
            identifier = "\(identifier)-campaign-\(campaignID.rawValue)"
        }
        
        return identifier
    }()
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let attributes: Attributes = [
            "experience": experience,
            "screen": screen
        ]
        
        let event = EventInfo(name: "Screen Presented", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
        
        sessionController.registerSession(identifier: sessionIdentifier) { [attributes] duration in
            var attributes = attributes
            attributes["duration"] = duration
            return EventInfo(name: "Screen Viewed", namespace: "rover", attributes: attributes)
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let attributes: Attributes = [
            "experience": experience,
            "screen": screen
        ]
        
        let event = EventInfo(name: "Screen Dismissed", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
        
        sessionController.unregisterSession(identifier: sessionIdentifier)
    }
    
    @objc
    open func close() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: Configuration
    
    open func configureNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }
        
        // Background color
        
        navigationBar.barTintColor = {
            if !screen.titleBar.useDefaultStyle {
                return screen.titleBar.backgroundColor.uiColor
            }
            
            if let appearanceColor = UINavigationBar.appearance().barTintColor {
                return appearanceColor
            }
            
            if let defaultColor = UINavigationBar().barTintColor {
                return defaultColor
            }
            
            return UIColor(red: (247 / 255), green: (247 / 255), blue: (247 / 255), alpha: 1)
        }()
        
        // Button color
        
        navigationBar.tintColor = {
            if !screen.titleBar.useDefaultStyle {
                return screen.titleBar.buttonColor.uiColor
            }
            
            if let appearanceColor = UINavigationBar.appearance().tintColor {
                return appearanceColor
            }
            
            if let defaultColor = UINavigationBar().tintColor {
                return defaultColor
            }
            
            return UIColor(red: 0.0, green: 122 / 255, blue: 1.0, alpha: 1)
        }()
        
        // Title color
        
        #if swift(>=4.2)
        var nextAttributes = navigationBar.titleTextAttributes ?? [NSAttributedString.Key: Any]()
        nextAttributes[NSAttributedString.Key.foregroundColor] = {
            if !screen.titleBar.useDefaultStyle {
                return screen.titleBar.textColor.uiColor
            }
            
            if let appearanceColor = UINavigationBar.appearance().titleTextAttributes?[NSAttributedString.Key.foregroundColor] as? UIColor {
                return appearanceColor
            }
            
            if let defaultColor = UINavigationBar().titleTextAttributes?[NSAttributedString.Key.foregroundColor] as? UIColor {
                return defaultColor
            }
            
            return UIColor.black
        }()
        #else
        var nextAttributes = navigationBar.titleTextAttributes ?? [NSAttributedStringKey: Any]()
        nextAttributes[NSAttributedStringKey.foregroundColor] = {
            if !screen.titleBar.useDefaultStyle {
                return screen.titleBar.textColor.uiColor
            }
            
            if let appearanceColor = UINavigationBar.appearance().titleTextAttributes?[NSAttributedStringKey.foregroundColor] as? UIColor {
                return appearanceColor
            }
            
            if let defaultColor = UINavigationBar().titleTextAttributes?[NSAttributedStringKey.foregroundColor] as? UIColor {
                return defaultColor
            }
            
            return UIColor.black
        }()
        #endif
        
        navigationBar.titleTextAttributes = nextAttributes
    }
    
    open func configureNavigationItem() {
        switch screen.titleBar.buttons {
        case .back:
            navigationItem.rightBarButtonItem = nil
            navigationItem.setHidesBackButton(false, animated: true)
        case .both:
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(close))
            navigationItem.setHidesBackButton(false, animated: true)
        case .close:
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(close))
            navigationItem.setHidesBackButton(true, animated: true)
        }
    }
    
    open func configureTitle() {
        title = screen.titleBar.text
    }
    
    open func configureBackgroundColor() {
        collectionView?.backgroundColor = screen.background.color.uiColor
    }
    
    open func configureBackgroundImage() {
        let backgroundImageView = collectionView!.backgroundView as! UIImageView
        backgroundImageView.alpha = 0.0
        backgroundImageView.image = nil
        
        // Background color is used for tiled backgrounds
        backgroundImageView.backgroundColor = UIColor.clear
        
        let background = screen.background
        
        switch background.contentMode {
        case .fill:
            backgroundImageView.contentMode = .scaleAspectFill
        case .fit:
            backgroundImageView.contentMode = .scaleAspectFit
        case .original:
            backgroundImageView.contentMode = .center
        case .stretch:
            backgroundImageView.contentMode = .scaleToFill
        case .tile:
            backgroundImageView.contentMode = .center
        }
        
        guard let configuration = ImageConfiguration(background: background, frame: backgroundImageView.frame) else {
            return
        }
        
        if let image = imageStore.fetchedImage(for: configuration) {
            if case .tile = background.contentMode {
                backgroundImageView.backgroundColor = UIColor(patternImage: image)
            } else {
                backgroundImageView.image = image
            }
            backgroundImageView.alpha = 1.0
        } else {
            imageStore.fetchImage(for: configuration) { [weak backgroundImageView] image in
                guard let image = image else {
                    return
                }

                if case .tile = background.contentMode {
                    backgroundImageView?.backgroundColor = UIColor(patternImage: image)
                } else {
                    backgroundImageView?.image = image
                }
                
                UIView.animate(withDuration: 0.25) {
                    backgroundImageView?.alpha = 1.0
                }
            }
        }
    }
    
    // MARK: Reuseable Views
    
    open func registerReusableViews() {
        collectionView?.register(BlockCell.self, forCellWithReuseIdentifier: "block")
        collectionView?.register(BarcodeCell.self, forCellWithReuseIdentifier: "barcode")
        collectionView?.register(ButtonCell.self, forCellWithReuseIdentifier: "button")
        collectionView?.register(ImageCell.self, forCellWithReuseIdentifier: "image")
        collectionView?.register(TextCell.self, forCellWithReuseIdentifier: "text")
        collectionView?.register(WebViewCell.self, forCellWithReuseIdentifier: "webView")
        collectionView?.register(RowView.self, forSupplementaryViewOfKind: "row", withReuseIdentifier: "row")
    }
    
    open func cellReuseIdentifier(at indexPath: IndexPath) -> String {
        let block = screen.rows[indexPath.section].blocks[indexPath.row]
        
        switch block {
        case _ as BarcodeBlock:
            return "barcode"
        case _ as ButtonBlock:
            return "button"
        case _ as ImageBlock:
            return "image"
        case _ as TextBlock:
            return "text"
        case _ as WebViewBlock:
            return "webView"
        default:
            return "block"
        }
    }
    
    open func supplementaryViewReuseIdentifier(at indexPath: IndexPath) -> String {
        return "row"
    }
    
    // MARK: UICollectionViewDataSource
    
    override open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return screen.rows[section].blocks.count
    }
    
    override open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return screen.rows.count
    }
    
    override open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reuseIdentifier = cellReuseIdentifier(at: indexPath)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        
        if let attributes = collectionViewLayout.layoutAttributesForItem(at: indexPath) as? ScreenLayoutAttributes, let clipRect = attributes.clipRect {
            let maskLayer = CAShapeLayer()
            maskLayer.path = CGPath(rect: clipRect, transform: nil)
            cell.layer.mask = maskLayer
        } else {
            cell.layer.mask = nil
        }
        
        guard let blockCell = cell as? BlockCell else {
            return cell
        }
        
        let block = screen.rows[indexPath.section].blocks[indexPath.row]
        blockCell.configure(with: block, imageStore: imageStore)
        return blockCell
    }
    
    override open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let reuseIdentifier = supplementaryViewReuseIdentifier(at: indexPath)
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: reuseIdentifier, withReuseIdentifier: reuseIdentifier, for: indexPath)
        
        guard let rowView = view as? RowView else {
            return view
        }
        
        let row = screen.rows[indexPath.section]
        rowView.configure(with: row, imageStore: imageStore)
        return rowView
    }
    
    // MARK: UICollectionViewDataSourcePrefetching
    
    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { indexPath in
            guard let frame = collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame else {
                return
            }
            
            let block = screen.rows[indexPath.section].blocks[indexPath.row]
            if let configuration = ImageConfiguration(background: block.background, frame: frame) {
                imageStore.fetchImage(for: configuration, completionHandler: nil)
            }
            
            if let block = block as? ImageBlock {
                let configuration = ImageConfiguration(image: block.image, frame: frame)
                imageStore.fetchImage(for: configuration, completionHandler: nil)
            }
        }
    }
    
    // MARK: UICollectionViewDelegate
    
    override open func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        // No-op if the block does not have any meaningful behavior to avoid every rectangle, line, image etc. tracking events
        
        switch screen.rows[indexPath.section].blocks[indexPath.row].tapBehavior {
        case .none:
            return false
        default:
            return true
        }
    }
    
    override open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
        
        let row = screen.rows[indexPath.section]
        let block = row.blocks[indexPath.row]
        
        let attributes: Attributes = [
            "experience": experience,
            "screen": screen,
            "row": row,
            "block": block
        ]
        
        switch block.tapBehavior {
        case .goToScreen(let screenID):
            if let nextScreen = experience.screens.first(where: { $0.id == screenID }), let navigationController = navigationController {
                if let viewController = viewControllerProvider(experience, nextScreen) {
                    navigationController.pushViewController(viewController, animated: true)
                }
            }
        case .none:
            break
        case let .openURL(url, dismiss):
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            
            if dismiss {
                self.dismiss(animated: true, completion: nil)
            }
        case .presentWebsite(let url):
            if let action = presentWebsiteActionProvider(url) {
                dispatcher.dispatch(action, completionHandler: nil)
            }
        }
        
        let event = EventInfo(name: "Block Tapped", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
    }
}
