//
//  ScreenViewController.swift
//  Rover
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
    public let campaignID: String?
    public let screen: Screen
    
    public let sessionController: SessionController
    
    public typealias ViewControllerProvider = (Experience, Screen) -> UIViewController?
    public let viewControllerProvider: ViewControllerProvider
    
    public typealias PresentWebsite = (URL, UIViewController) -> Void
    public let presentWebsite: PresentWebsite
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        switch screen.statusBar.style {
        case .dark:
            return .default
        case .light:
            return .lightContent
        }
    }
    
    public init(
        collectionViewLayout: UICollectionViewLayout,
        experience: Experience,
        campaignID: String?,
        screen: Screen,
        sessionController: SessionController,
        viewControllerProvider: @escaping ViewControllerProvider,
        presentWebsite: @escaping PresentWebsite
    ) {
        self.experience = experience
        self.campaignID = campaignID
        self.screen = screen
        self.sessionController = sessionController
        self.viewControllerProvider = viewControllerProvider
        self.presentWebsite = presentWebsite
        
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
        var identifier = "experience-\(experience.id)-screen-\(screen.id)"
        
        if let campaignID = self.campaignID {
            identifier = "\(identifier)-campaign-\(campaignID)"
        }
        
        return identifier
    }()
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var userInfo: [String: Any] = [
            ScreenViewController.experienceUserInfoKey: experience,
            ScreenViewController.screenUserInfoKey: screen
        ]
        
        if let campaignID = campaignID {
            userInfo[ScreenViewController.campaignIDUserInfoKey] = campaignID
        }
        
        NotificationCenter.default.post(
            name: ScreenViewController.screenPresentedNotification,
            object: self,
            userInfo: userInfo
        )
        
        sessionController.registerSession(identifier: sessionIdentifier) { [weak self] duration in
            userInfo[ScreenViewController.durationUserInfoKey] = duration
            NotificationCenter.default.post(
                name: ScreenViewController.screenViewedNotification,
                object: self,
                userInfo: userInfo
            )
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        var userInfo: [String: Any] = [
            ScreenViewController.experienceUserInfoKey: experience,
            ScreenViewController.screenUserInfoKey: screen
        ]
        
        if let campaignID = campaignID {
            userInfo[ScreenViewController.campaignIDUserInfoKey] = campaignID
        }
        
        NotificationCenter.default.post(
            name: ScreenViewController.screenDismissedNotification,
            object: self,
            userInfo: userInfo
        )
        
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
        
        if let image = ImageStore.shared.image(for: background, frame: backgroundImageView.frame) {
            if case .tile = background.contentMode {
                backgroundImageView.backgroundColor = UIColor(patternImage: image)
            } else {
                backgroundImageView.image = image
            }
            backgroundImageView.alpha = 1.0
        } else {
            ImageStore.shared.fetchImage(for: background, frame: backgroundImageView.frame) { [weak backgroundImageView] image in
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
        blockCell.configure(with: block)
        return blockCell
    }
    
    override open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let reuseIdentifier = supplementaryViewReuseIdentifier(at: indexPath)
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: reuseIdentifier, withReuseIdentifier: reuseIdentifier, for: indexPath)
        
        guard let rowView = view as? RowView else {
            return view
        }
        
        let row = screen.rows[indexPath.section]
        rowView.configure(with: row)
        return rowView
    }
    
    // MARK: UICollectionViewDataSourcePrefetching
    
    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { indexPath in
            guard let frame = collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame else {
                return
            }
            
            let block = screen.rows[indexPath.section].blocks[indexPath.row]
            ImageStore.shared.fetchImage(for: block.background, frame: frame)
            
            if let image = (block as? ImageBlock)?.image {
                ImageStore.shared.fetchImage(for: image, frame: frame)
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
            presentWebsite(url, self)
        }
        
        var userInfo: [String: Any] = [
            ScreenViewController.experienceUserInfoKey: experience,
            ScreenViewController.screenUserInfoKey: screen,
            ScreenViewController.blockUserInfoKey: block
        ]
        
        if let campaignID = campaignID {
            userInfo[ScreenViewController.campaignIDUserInfoKey] = campaignID
        }
        
        NotificationCenter.default.post(
            name: ScreenViewController.blockTappedNotification,
            object: self,
            userInfo: userInfo
        )
    }
}

extension ScreenViewController {
    /// The `ScreenViewController` sends this notification when it is presented.
    public static let screenPresentedNotification = Notification.Name("io.rover.screenPresentedNotification")
    
    /// The `ScreenViewController` sends this notification when it is dismissed.
    public static let screenDismissedNotification = Notification.Name("io.rover.screenDismissedNotification")
    
    /// The `ScreenViewController` sends this notification when a user finishes viewing a screen. The user starts
    /// viewing a screen when the view controller is presented and finishes when it is dismissed. The duration the
    /// user viewed the screen is included in the `durationUserInfoKey`.
    ///
    /// If the user quickly dismisses the view controller and presents it again (or backgrounds the app and restores it)
    /// the view controller considers this part of the same "viewing session". The notification is not sent until the
    /// user dismisses the view controller and a specified time passes (default is 10 seconds).
    ///
    /// This notification is useful for tracking the amount of time users spend viewing a screen. However if you want to
    /// be notified immediately when a user views a screen you should use the `screenPresentedNotification`.
    public static let screenViewedNotification = Notification.Name("io.rover.screenViewedNotification")
    
    /// The `ScreenViewController` sends this when a `UIView` representing a specific block somewhere within the view
    /// controller's hierarchy was tapped by the user.
    public static let blockTappedNotification = Notification.Name("io.rover.blockTappedNotification")
}

// MARK: User Info Keys

extension ScreenViewController {
    /// A key whose value is the `Experience` associated with the `ScreenViewController`.
    public static let experienceUserInfoKey = "experienceUserInfoKey"
    
    /// A key whose value is the `Screen` associated with the `ScreenViewController`.
    public static let screenUserInfoKey = "screenUserInfoKey"
    
    /// A key whose value is the `Block` that was tapped which triggered a `blockTappedNotification`.
    public static let blockUserInfoKey = "blockUserInfoKey"
    
    /// A key whose value is an optional `String` containing the `campaignID` passed into the `RoverViewController` when
    /// it was initialized.
    public static let campaignIDUserInfoKey = "campaignIDUserInfoKey"
    
    /// A key whose value is a `Double` representing the duration of an experience session.
    public static let durationUserInfoKey = "durationUserInfoKey"
}
