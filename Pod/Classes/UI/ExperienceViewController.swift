//
//  ExperienceViewController.swift
//  Pods
//
//  Created by Ata Namvari on 2016-08-11.
//
//

import Foundation

protocol ExperienceViewControllerDelegate: class {
    func experienceViewControllerDidLaunch(viewController: ExperienceViewController)
    func experienceViewController(viewController: ExperienceViewController, didViewScreen screen: Screen)
    func experienceViewController(viewController: ExperienceViewController, didPressBlock block: Block, screen: Screen)
}

public class ExperienceViewController: ModalViewController {
    
    internal(set) static weak var superDelegate: ExperienceViewControllerDelegate?
    
    var experience: Experience?
    var operationQueue = NSOperationQueue()
    
    required public init(identifier: String) {
        super.init(rootViewController: LoadingViewController())
        view.backgroundColor = UIColor.whiteColor()
        fetchExperience(identifier: identifier)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    func fetchExperience(identifier identifier: String) {
        let mappingOperation = MappingOperation { (experience: Experience) in
            self.experience = experience
            dispatch_async(dispatch_get_main_queue(), { 
                self.reloadExperience()
            })
        }
        
        // TODO: Handle bad internet and reload capabilities with the spinner
        
        let networkOperation = NetworkOperation(urlRequest: Router.GetExperience(identifier).urlRequest) {
            [unowned mappingOperation]
            (JSON, error) in
            
            mappingOperation.json = JSON
        }
        
        mappingOperation.addDependency(networkOperation)
        
        operationQueue.addOperation(networkOperation)
        operationQueue.addOperation(mappingOperation)
    }
    
    func reloadExperience() {
        guard let homeScreen = experience?.homeScreen else { return }
        
        // Track Experience
        ExperienceViewController.superDelegate?.experienceViewControllerDidLaunch(self)
        
        let viewController = self.viewController(screen: homeScreen)
        addCloseButtonToViewController(viewController)
        viewControllers = [viewController]
        
        // Track HomeScreen
        ExperienceViewController.superDelegate?.experienceViewController(self, didViewScreen: homeScreen)
    }
    
    func viewController(screen screen: Screen) -> ScreenViewController {
        let screenViewController = ScreenViewController(screen: screen)
        screenViewController.delegate = self
        return screenViewController
    }
    
    public override func pushViewController(viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        
        // Track Screen
        guard let vc = viewController as? ScreenViewController, screen = vc.screen else { return }
        ExperienceViewController.superDelegate?.experienceViewController(self, didViewScreen: screen)
    }
    
    public override func popViewControllerAnimated(animated: Bool) -> UIViewController? {
        let vc = super.popViewControllerAnimated(animated)
        
        // Track Screen
        if let viewController = vc as? ScreenViewController, screen = viewController.screen {
            ExperienceViewController.superDelegate?.experienceViewController(self, didViewScreen: screen)
        }
        
        return vc
    }
}

extension ExperienceViewController : ScreenViewControllerDelegate {
    public func screenViewController(viewController: ScreenViewController, handleOpenScreenWithIdentifier identifier: String) {
        guard let screen = experience?.screens.filter({ $0.identifier == identifier}).first else { return }
        let viewController = self.viewController(screen: screen)
        pushViewController(viewController, animated: true)
    }
    
    public func screenViewController(viewController: ScreenViewController, didPressBlock block: Block) {
        guard let screen = viewController.screen else { return }
        ExperienceViewController.superDelegate?.experienceViewController(self, didPressBlock: block, screen: screen)
    }
}

class LoadingViewController : UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
    }
}