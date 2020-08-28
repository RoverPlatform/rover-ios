//
//  ScreenViewController.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import SafariServices
import UIKit

// swiftlint:disable type_body_length

/// The `ScreenViewController` displays a Rover screen within an `ExperienceViewController` and is responsible for
/// handling button taps. It posts [`Notification`s](https://developer.apple.com/documentation/foundation/notification)
/// through the default [`NotificationCenter`](https://developer.apple.com/documentation/foundation/notificationcenter)
/// when it is presented, dismissed and viewed.
open class ScreenViewController: UICollectionViewController, UICollectionViewDataSourcePrefetching, PollCellDelegate {
    
    public let experience: Experience
    public let campaignID: String?
    public let screen: Screen
    public let viewControllerFactory: (Experience, Screen) -> UIViewController?
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        switch screen.statusBar.style {
        case .dark:            
            #if swift(>=5.1)
            if #available(iOS 13.0, *) {
                return .darkContent
            } else {
                return .default
            }
            #else
            return .default
            #endif
        case .light:
            return .lightContent
        }
    }
    
    public init(
        collectionViewLayout: UICollectionViewLayout,
        experience: Experience,
        campaignID: String?,
        screen: Screen,
        viewControllerFactory: @escaping (Experience, Screen) -> UIViewController?
    ) {
        self.experience = experience
        self.campaignID = campaignID
        self.screen = screen
        self.viewControllerFactory = viewControllerFactory
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
    
    @objc
    open func close() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: Notifications
    
    private var sessionIdentifier: String {
        var identifier = "experience-\(experience.id)-screen-\(screen.id)"
        
        if let campaignID = self.campaignID {
            identifier = "\(identifier)-campaign-\(campaignID)"
        }
        
        return identifier
    }
    
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
        
        SessionController.shared.registerSession(identifier: sessionIdentifier) { [weak self] duration in
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
        
        SessionController.shared.unregisterSession(identifier: sessionIdentifier)
    }
    
    // MARK: Configuration
    
    private func configureNavigationBar() {
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
    
    private func configureNavigationItem() {
        switch screen.titleBar.buttons {
        case .back:
            navigationItem.rightBarButtonItem = nil
            navigationItem.setHidesBackButton(false, animated: true)
        case .both:
            navigationItem.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(close))
            navigationItem.setHidesBackButton(false, animated: true)
        case .close:
            navigationItem.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(close))
            navigationItem.setHidesBackButton(true, animated: true)
        }
    }
    
    private func configureTitle() {
        title = screen.titleBar.text
    }
    
    private func configureBackgroundColor() {
        collectionView?.backgroundColor = screen.background.color.uiColor
    }
    
    private func configureBackgroundImage() {
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
    
    /// Register the `UITableViewCell` class to use for each of the various block types and the supplementary view class
    /// to use for rows. You can override this method to provide a custom cell for a specific block.
    open func registerReusableViews() {
        collectionView?.register(
            BlockCell.self,
            forCellWithReuseIdentifier: ScreenViewController.blockCellReuseIdentifier
        )
        
        collectionView?.register(
            BarcodeCell.self,
            forCellWithReuseIdentifier: ScreenViewController.barcodeCellReuseIdentifier
        )
        
        collectionView?.register(
            ButtonCell.self,
            forCellWithReuseIdentifier: ScreenViewController.buttonCellReuseIdentifier
        )
        
        collectionView?.register(
            ImageCell.self,
            forCellWithReuseIdentifier: ScreenViewController.imageCellReuseIdentifier
        )
        
        collectionView?.register(
            TextCell.self,
            forCellWithReuseIdentifier: ScreenViewController.textCellReuseIdentifier
        )
        
        collectionView?.register(
            WebViewCell.self,
            forCellWithReuseIdentifier: ScreenViewController.webViewCellReuseIdentifier
        )
        
        collectionView?.register(
            TextPollCell.self,
            forCellWithReuseIdentifier: ScreenViewController.textPollViewCellReuseIdentifier
        )
        
        collectionView.register(
            ImagePollCell.self,
            forCellWithReuseIdentifier: ScreenViewController.imagePollViewCellReuseIdentifier
        )
        
        collectionView?.register(
            RowView.self,
            forSupplementaryViewOfKind: "row",
            withReuseIdentifier: ScreenViewController.rowSupplementaryViewReuseIdentifier
        )
    }
    
    private func cellReuseIdentifier(at indexPath: IndexPath) -> String {
        let block = screen.rows[indexPath.section].blocks[indexPath.row]
        
        switch block {
        case _ as BarcodeBlock:
            return ScreenViewController.barcodeCellReuseIdentifier
        case _ as ButtonBlock:
            return ScreenViewController.buttonCellReuseIdentifier
        case _ as ImageBlock:
            return ScreenViewController.imageCellReuseIdentifier
        case _ as TextBlock:
            return ScreenViewController.textCellReuseIdentifier
        case _ as WebViewBlock:
            return ScreenViewController.webViewCellReuseIdentifier
        case _ as TextPollBlock:
            return ScreenViewController.textPollViewCellReuseIdentifier
        case _ as ImagePollBlock:
            return ScreenViewController.imagePollViewCellReuseIdentifier
        default:
            return ScreenViewController.blockCellReuseIdentifier
        }
    }
    
    private func supplementaryViewReuseIdentifier(at indexPath: IndexPath) -> String {
        return ScreenViewController.rowSupplementaryViewReuseIdentifier
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
        
        
        if let pollCell = cell as? PollCell {
            pollCell.delegate = self
        }
        
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
        
        if let pollCell = blockCell as? PollCell {
            pollCell.experienceID = self.experience.id
        }
        
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
    
    open func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
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
        let row = screen.rows[indexPath.section]
        let block = row.blocks[indexPath.row]
        
        return block is ButtonBlock || block.tapBehavior != BlockTapBehavior.none
    }
    
    override open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
        
        let row = screen.rows[indexPath.section]
        let block = row.blocks[indexPath.row]
        
        switch block.tapBehavior {
        case .goToScreen(let screenID):
            navigateToScreen(screenID: screenID)
        case .none, .custom:
            break
        case let .openURL(url, dismiss):
            openURL(url, dismiss: dismiss)
        case .presentWebsite(let url):
            presentWebsite(at: url)
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
    
    // MARK: Block Tap Actions
    
    /// Navigate to another screen in the experience. This method is called by the `ScreenViewController` in response
    /// to a block tap configured to navigate to a screen. The default implementation constructs a new view controller
    /// using the `viewControllerFactory` and pushes it onto the navigation stack. You can override this method if you
    /// need to change this behavior.
    open func navigateToScreen(screenID: String) {
        guard let nextScreen = experience.screens.first(where: { $0.id == screenID }), let navigationController = navigationController else {
            return
        }
        
        if let viewController = viewControllerFactory(experience, nextScreen) {
            navigationController.pushViewController(viewController, animated: true)
        }
    }
    
    /// Open a URL. This method is called by the `ScreenViewController` in response to a block tap configured to
    /// open a URL. The default implementation calls `open(_:options:completionHandler:)` on `UIApplication.shared` and
    /// dismisses the entire experience if the `dismiss` paramter is true. You can override this method if you need to
    /// change this behavior.
    open func openURL(_ url: URL, dismiss: Bool) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        
        if dismiss {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    /// Present a website at the given URL in a view controller. This method is called by the `ScreenViewController` in
    /// response to a block tap configured to present a website. The default implementation constructs a new view
    /// controller by calling the `websiteViewController(url:)` factory method and presents it modally. You can override
    /// this method if you need to change this behavior.
    open func presentWebsite(at url: URL) {
        let websiteViewController = self.websiteViewController(url: url)
        present(websiteViewController, animated: true, completion: nil)
    }
    
    // MARK: Poll Answer
    
    func didCastVote(on pollBlock: PollBlock, for option: PollOption) {
        var userInfo: [String: Any] = [
            ScreenViewController.experienceUserInfoKey: experience,
            ScreenViewController.screenUserInfoKey: screen,
            ScreenViewController.blockUserInfoKey: pollBlock,
            ScreenViewController.optionUserInfoKey: option
        ]
        
        if let campaignID = campaignID {
            userInfo[ScreenViewController.campaignIDUserInfoKey] = campaignID
        }
        
        NotificationCenter.default.post(
            name: ScreenViewController.pollAnsweredNotification,
            object: self,
            userInfo: userInfo
        )
    }
    
    // MARK: Factories
    
    /// Construct a view controller to use for presenting websites. The default implementation returns an instance
    /// of `SFSafariViewController`. You can override this method if you want to use a different view controller.
    open func websiteViewController(url: URL) -> UIViewController {
        return SFSafariViewController(url: url)
    }
}

// MARK: Reuse Identifiers

extension ScreenViewController {
    public static let blockCellReuseIdentifier = "block"
    public static let barcodeCellReuseIdentifier = "barcode"
    public static let buttonCellReuseIdentifier = "button"
    public static let imageCellReuseIdentifier = "image"
    public static let textCellReuseIdentifier = "text"
    public static let webViewCellReuseIdentifier = "webView"
    public static let rowSupplementaryViewReuseIdentifier = "row"
    public static let textPollViewCellReuseIdentifier = "textPoll"
    public static let imagePollViewCellReuseIdentifier = "imagePoll"
}

// MARK: Notifications

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
    
    /// The `ScreenViewController` sends this notification when a user casts a vote on a Poll in an experience.
    public static let pollAnsweredNotification = Notification.Name("io.rover.pollAnsweredNotification")
}

// MARK: User Info Keys

extension ScreenViewController {
    /// A key whose value is the `Experience` associated with the `ScreenViewController`.
    public static let experienceUserInfoKey = "experienceUserInfoKey"
    
    /// A key whose value is the `Screen` associated with the `ScreenViewController`.
    public static let screenUserInfoKey = "screenUserInfoKey"
    
    /// A key whose value is the `Block` that was tapped which triggered a `blockTappedNotification`.
    public static let blockUserInfoKey = "blockUserInfoKey"
    
    /// A key whose value is the poll `Option` that was tapped which triggered a `pollAnsweredNotification`.
    public static let optionUserInfoKey = "optionUserInfoKey"
    
    /// A key whose value is an optional `String` containing the `campaignID` passed into the `RoverViewController` when
    /// it was initialized.
    public static let campaignIDUserInfoKey = "campaignIDUserInfoKey"
    
    /// A key whose value is a `Double` representing the duration of an experience session.
    public static let durationUserInfoKey = "durationUserInfoKey"
}
