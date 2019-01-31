//
//  NotificationCenterViewController.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-02-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import os
import UIKit

open class NotificationCenterViewController: UIViewController {
    public let eventPipeline: EventPipeline
    public let router: Router
    public let imageStore: ImageStore
    public let sessionController: SessionController
    public let syncCoordinator: SyncCoordinator
    public let managedObjectContext: NSManagedObjectContext
    
    public typealias WebsiteViewControllerProvider = (URL) -> UIViewController?
    public let websiteViewControllerProvider: WebsiteViewControllerProvider
    
    public private(set) var navigationBar: UINavigationBar?
    public private(set) var refreshControl = UIRefreshControl()
    public private(set) var tableView = UITableView()
    
    private var didBecomeActiveObserver: NSObjectProtocol?
    
    public init(
        eventPipeline: EventPipeline,
        router: Router,
        imageStore: ImageStore,
        sessionController: SessionController,
        syncCoordinator: SyncCoordinator,
        managedObjectContext: NSManagedObjectContext,
        websiteViewControllerProvider: @escaping WebsiteViewControllerProvider
    ) {
        self.eventPipeline = eventPipeline
        self.router = router
        self.imageStore = imageStore
        self.sessionController = sessionController
        self.syncCoordinator = syncCoordinator
        self.managedObjectContext = managedObjectContext
        self.websiteViewControllerProvider = websiteViewControllerProvider
        
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.white
        title = "Notification Center"
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        tableView.delegate = self
        tableView.dataSource = self
        fetchedResultsController.delegate = self
        
        registerReusableViews()

        #if swift(>=4.2)
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            if self?.viewIfLoaded?.window != nil {
                self?.resetApplicationIconBadgeNumber()
            }
        }
        #else
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main) { [weak self] _ in
            if self?.viewIfLoaded?.window != nil {
                self?.resetApplicationIconBadgeNumber()
            }
        }
        #endif
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Problem fetching notifications list: %s", log: .ui, error.localizedDescription)
        }
    }
    
    /// Reset the application icon badge number to 0 any time the notification center is viewed, regardless of the number of unread messages
    func resetApplicationIconBadgeNumber() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        makeNavigationBar()
        configureConstraints()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let event = EventInfo(name: "Notification Center Presented", namespace: "rover")
        self.eventPipeline.addEvent(event)
        
        sessionController.registerSession(identifier: "notificationCenter") { duration in
            let attributes: Attributes = ["duration": duration]
            return EventInfo(name: "Notification Center Viewed", namespace: "rover", attributes: attributes)
        }
        
        if UIApplication.shared.applicationState == .active {
            resetApplicationIconBadgeNumber()
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let event = EventInfo(name: "Notification Center Dismissed", namespace: "rover")
        self.eventPipeline.addEvent(event)
        
        sessionController.unregisterSession(identifier: "notificationCenter")
    }
    
    // MARK: Layout
    
    open func makeNavigationBar() {
        if let existingNavigationBar = self.navigationBar {
            existingNavigationBar.removeFromSuperview()
        }
        
        if navigationController != nil {
            self.navigationBar = nil
            return
        }
        
        let navigationBar = UINavigationBar()
        navigationBar.delegate = self
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        
        let navigationItem = makeNavigationItem()
        navigationBar.items = [navigationItem]
        
        view.addSubview(navigationBar)
        self.navigationBar = navigationBar
    }
    
    open func makeNavigationItem() -> UINavigationItem {
        let navigationItem = UINavigationItem()
        navigationItem.title = title
        
        if presentingViewController != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done(_:)))
        }
        
        return navigationItem
    }
        
    open func configureConstraints() {
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        if let navigationBar = navigationBar {
            NSLayoutConstraint.activate([
                navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
        
        if #available(iOS 11, *) {
            let layoutGuide = view.safeAreaLayoutGuide
            tableView.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor).isActive = true
            
            if let navigationBar = navigationBar {
                NSLayoutConstraint.activate([
                    navigationBar.topAnchor.constraint(equalTo: layoutGuide.topAnchor),
                    tableView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor)
                ])
            } else {
                tableView.topAnchor.constraint(equalTo: layoutGuide.topAnchor).isActive = true
            }
        } else {
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            
            if let navigationBar = navigationBar {
                NSLayoutConstraint.activate([
                    navigationBar.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
                    tableView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor)
                ])
            } else {
                tableView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor).isActive = true
            }
        }
    }
    
    // MARK: Actions
    
    @objc
    func done(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc
    func refresh(_ sender: Any) {
        self.syncCoordinator.sync { _ in
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    // MARK: Reuseable Views
    
    open func registerReusableViews() {
        tableView.register(NotificationCell.self, forCellReuseIdentifier: "notification")
    }
    
    // MARK: Core Data
    
    open lazy var fetchRequest: NSFetchRequest<RoverData.Notification> = {
        let fetchRequest: NSFetchRequest<RoverData.Notification> = RoverData.Notification.fetchRequest()
        fetchRequest.predicate = self.predicate
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(RoverData.Notification.deliveredAt), ascending: false)
        ]
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    /// Returns a filtered list of notifications from dataStore.notifications. The default implementation filters out notifications that aren't notification center enabled, are deleted or have expired. This method is called automatically by the NotificationCenterTableView and the results are cached for performance.
    ///
    /// You can override this method if you wish to modify the rules used to filter notifications. For example if you wish to include expired notifications in the table view and instead show their expired status with a visual indicator.
    open lazy var predicate: NSPredicate? = nil
    
    open lazy var fetchedResultsController: NSFetchedResultsController<RoverData.Notification> = NSFetchedResultsController(
        fetchRequest: fetchRequest,
        managedObjectContext: managedObjectContext,
        sectionNameKeyPath: nil,
        cacheName: nil
    )
}

// MARK: UITableViewDelegate

extension NotificationCenterViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        openNotification(at: indexPath)
        
        // Prevents the highlighted state from persisting
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // Swipe to delete in iOS 10
    
    public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [UITableViewRowAction(style: .destructive, title: "Delete") { _, indexPath in
            self.deleteNotification(at: indexPath)
        }]
    }
    
    // Swipe to delete in iOS 11
    
    @available(iOS 11.0, *)
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Delete") { _, _, _ in
                self.deleteNotification(at: indexPath)
            }
        ])
    }
    
    func openNotification(at indexPath: IndexPath) {
        let notification = self.notificationAt(indexPath: indexPath)
        
        if !notification.isRead {
            notification.markRead()
        }

        // TODO: Restore this once TapBehaviour is available on Campaign.
        
        //        switch notification.tapBehavior {
        //        case is OpenAppTapBehavior:
        //            break
        //        case let tapBehavior as OpenURLTapBehavior:
        //            let url = tapBehavior.url
        //            if let viewController = router.viewController(for: url) {
        //                viewController.transitioningDelegate = self
        //                self.present(viewController, animated: true)
        //            } else {
        //                // non-Rover URI
        //                UIApplication.shared.open(url, options: [:], completionHandler: nil)
        //            }
        //        case let tapBehavior as PresentWebsiteTapBehavior:
        //            let url = tapBehavior.url
        //            if let websiteViewController = websiteViewControllerProvider(url) {
        //                websiteViewController.transitioningDelegate = self
        //                self.present(websiteViewController, animated: true)
        //            }
        //        default:
        //            break
        //        }
        
        let eventInfo = notification.openedEvent(source: .notificationCenter)
        eventPipeline.addEvent(eventInfo)
    }
    
    func deleteNotification(at indexPath: IndexPath) {
        let notification = self.notificationAt(indexPath: indexPath)
        notification.delete()
    }
}

// MARK: UINavigationBarDelegate

extension NotificationCenterViewController: UINavigationBarDelegate {
    public func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

// MARK: UIViewControllerTransitioningDelegate

extension NotificationCenterViewController: UIViewControllerTransitioningDelegate {
    class SlideLeftAnimator: NSObject, UIViewControllerAnimatedTransitioning {
        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            guard let toViewController = transitionContext.viewController(forKey: .to) else {
                return
            }
            
            transitionContext.containerView.addSubview(toViewController.view)
            
            let finalFrame = transitionContext.finalFrame(for: toViewController)
            toViewController.view.frame = finalFrame.offsetBy(dx: finalFrame.width, dy: 0)
            
            let duration = transitionDuration(using: transitionContext)
            
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: .curveEaseInOut,
                animations: {
                    toViewController.view.frame = finalFrame
                }, completion: { finished in
                    transitionContext.completeTransition(finished)
                }
            )
        }
        
        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 0.35
        }
    }
    
    class SlideRightAnimator: NSObject, UIViewControllerAnimatedTransitioning {
        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            guard let toViewController = transitionContext.viewController(forKey: .to), let fromViewController = transitionContext.viewController(forKey: .from) else {
                return
            }
            
            transitionContext.containerView.insertSubview(toViewController.view, at: 0)
            
            let finalFrame = transitionContext.finalFrame(for: toViewController)
            let duration = transitionDuration(using: transitionContext)
            
            UIView.animate(
                withDuration: duration,
                animations: {
                    fromViewController.view.frame = finalFrame.offsetBy(dx: finalFrame.width, dy: 0)
                },
                completion: { finished in
                    transitionContext.completeTransition(finished)
                }
            )
        }
        
        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 0.35
        }
    }
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SlideLeftAnimator()
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SlideRightAnimator()
    }
}

extension NotificationCenterViewController: UITableViewDataSource {
    
    func notificationAt(indexPath: IndexPath) -> RoverData.Notification {
        return fetchedResultsController.object(at: indexPath) as RoverData.Notification
    }
    
    open func cellReuseIdentifier(at indexPath: IndexPath) -> String {
        return "notification"
    }
    
    // MARK: UITableViewDataSource
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = self.fetchedResultsController.sections else {
            assertionFailure("No sections in fetchedResultsController.")
            return 0
        }
        let sectionInfo = sections[section]
        return sectionInfo.numberOfObjects
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = self.cellReuseIdentifier(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        guard let notificationCell = cell as? NotificationCell else {
            return cell
        }
        
        let notification = self.notificationAt(indexPath: indexPath)
        notificationCell.configure(with: notification, imageStore: self.imageStore)
        return notificationCell
    }
}

extension NotificationCenterViewController: NSFetchedResultsControllerDelegate {
    open func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }
    
    open func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }
    
    open func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        case .update:
            if let indexPath = indexPath {
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                tableView.moveRow(at: indexPath, to: newIndexPath)
            }
        }
    }
}
