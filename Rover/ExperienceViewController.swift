//
//  ExperienceViewController.swift
//  Pods
//
//  Created by Ata Namvari on 2016-08-11.
//
//

import Foundation

protocol ExperienceViewControllerDelegate: class {
    func experienceViewControllerDidLaunch(_ viewController: ExperienceViewController)
    func experienceViewControllerDidDismiss(_ viewController: ExperienceViewController)
    func experienceViewController(_ viewController: ExperienceViewController, didViewScreen screen: Screen, referrerScreen: Screen?, referrerBlock: Block?)
    func experienceViewController(_ viewController: ExperienceViewController, didPressBlock block: Block, screen: Screen)
    func experienceViewController(_ viewController: ExperienceViewController, willLoadExperience experience: Experience)
}

open class ExperienceViewController: ModalViewController {
    
    internal(set) static weak var superDelegate: ExperienceViewControllerDelegate?
    
    var experience: Experience?
    var campaignID: String?
    var operationQueue = OperationQueue()
    
    let sessionID = NSUUID().uuidString
    
    required public init(identifier: String, useCurrentVersion: Bool = false, campaignID: String? = nil) {
        super.init(rootViewController: LoadingViewController())
        view.backgroundColor = UIColor.white
        
        self.campaignID = campaignID
        
        let request = useCurrentVersion ? Router.getCurrentExperience(identifier).urlRequest : Router.getExperience(identifier).urlRequest
        
        fetchExperience(identifier: identifier, request: request)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    func fetchExperience(identifier: String, request: URLRequest) {
        let mappingOperation = MappingOperation { (experience: Experience) in
            self.experience = experience
            DispatchQueue.main.async(execute: { 
                self.reloadExperience()
            })
        }
        
        // TODO: Handle bad internet and reload capabilities with the spinner
        
        let networkOperation = NetworkOperation(urlRequest: request) {
            [unowned mappingOperation]
            (JSON, error) in
            
            mappingOperation.json = JSON
        }
        
        mappingOperation.addDependency(networkOperation)
        
        operationQueue.addOperation(networkOperation)
        operationQueue.addOperation(mappingOperation)
    }
    
    func reloadExperience() {
        guard let experience = experience else { return }
        
        ExperienceViewController.superDelegate?.experienceViewController(self, willLoadExperience: experience)
        
        guard let homeScreen = experience.homeScreen else { return }
        
        // Track Experience
        ExperienceViewController.superDelegate?.experienceViewControllerDidLaunch(self)
        
        let viewController = self.viewController(screen: homeScreen)
        addCloseButtonToViewController(viewController)
        viewControllers = [viewController]
        
        // Track HomeScreen
        ExperienceViewController.superDelegate?.experienceViewController(self, didViewScreen: homeScreen, referrerScreen: nil, referrerBlock: nil)
    }
    
    func viewController(screen: Screen) -> ScreenViewController {
        let screenViewController = ScreenViewController(screen: screen)
        screenViewController.delegate = self
        return screenViewController
    }
    
    open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        
    }
    
    open override func popViewController(animated: Bool) -> UIViewController? {
        let vc = super.popViewController(animated: animated)
        
        // Track Screen
        if let viewController = topViewController as? ScreenViewController, let screen = viewController.screen {
            let svc = vc as? ScreenViewController
            let referrerScreen = svc?.screen
            ExperienceViewController.superDelegate?.experienceViewController(self, didViewScreen: screen, referrerScreen: referrerScreen, referrerBlock: nil)
        }
        
        return vc
    }
    
    override func dismissViewController() {
        super.dismissViewController()
        ExperienceViewController.superDelegate?.experienceViewControllerDidDismiss(self)
    }
}

extension ExperienceViewController : ScreenViewControllerDelegate {
    public func screenViewController(_ viewController: ScreenViewController, handleOpenScreenWithIdentifier identifier: String) {
        guard let screen = experience?.screens.filter({ $0.identifier == identifier}).first else { return }
        let viewController = self.viewController(screen: screen)
        pushViewController(viewController, animated: true)
    }
    
    public func screenViewController(_ viewController: ScreenViewController, didPressBlock block: Block) {
        guard let screen = viewController.screen else { return }
        ExperienceViewController.superDelegate?.experienceViewController(self, didPressBlock: block, screen: screen)
        
        
        // Track Screen
        switch block.action {
        case .screen(let identifier)?:
            guard let toScreen = experience?.screens.filter({ $0.identifier == identifier}).first else { break }
            ExperienceViewController.superDelegate?.experienceViewController(self, didViewScreen: toScreen, referrerScreen: screen, referrerBlock: block)
        default:
            break
        }
    }
}

class LoadingViewController : UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
    }
}
