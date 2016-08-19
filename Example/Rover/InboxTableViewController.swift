//
//  InboxTableViewController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-03-10.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import Rover

class InboxTableViewController: UITableViewController {

    var messages = [Message]()
    var unreadMessagesCount: Int = 0 {
        didSet {
            if unreadMessagesCount > 0 {
                self.navigationController?.tabBarItem.badgeValue = "\(unreadMessagesCount)"
            } else {
                self.navigationController?.tabBarItem.badgeValue = nil
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidOpen), name: UIApplicationDidFinishLaunchingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidOpen), name: UIApplicationWillEnterForegroundNotification, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(InboxTableViewController.reloadMessages), forControlEvents: .ValueChanged)
        
        Rover.addObserver(self)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        Rover.removeObserver(self)
    }
    
    func reloadMessages() {
        Rover.reloadInbox { messages, unread in
            self.refreshControl?.endRefreshing()
            self.messages = messages
            self.tableView.reloadData()
            
            self.unreadMessagesCount = unread
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MessageTableViewCellIdentifier", forIndexPath: indexPath) as! MessageTableViewCell
        let message = messages[indexPath.row]
        
        cell.titleLabel.text = message.title
        cell.messageTextLabel.text = message.text
        cell.unreadIndicatorView.hidden = message.read
        
        return cell
    }

    // MARK: - Table view delegate

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let message = messages[indexPath.row]
            messages.removeAtIndex(indexPath.row)
            Rover.deleteMessage(message)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let message = messages[indexPath.row]
        
        switch message.action {
        case .Website:
            fallthrough
        case .DeepLink:
            guard let url = message.url else { break }
            UIApplication.sharedApplication().openURL(url)
        case .LandingPage:
            if let screenViewController = Rover.viewController(message: message) as? ScreenViewController {
                screenViewController.delegate = self
                navigationController?.pushViewController(screenViewController, animated: true)
            }
            break
        case .Experience:
            if let experienceId = message.experienceId {
                let experienceViewController = ExperienceViewController(identifier: experienceId)
                presentViewController(experienceViewController, animated: true, completion: nil)
            }
        default:
            break
        }
        
        Rover.trackMessageOpenEvent(message)
        
        if (!message.read) {
            message.read = true
            self.unreadMessagesCount -= 1
            Rover.patchMessage(message)
            
            let cell = tableView.cellForRowAtIndexPath(indexPath) as! MessageTableViewCell
            cell.unreadIndicatorView.hidden = true
        }
    }
    
    // MARK: Application Observer
    
    func applicationDidOpen() {
        reloadMessages()
    }

}

extension InboxTableViewController : ScreenViewControllerDelegate {
    func screenViewController(viewController: ScreenViewController, handleOpenURL url: NSURL) {
        UIApplication.sharedApplication().openURL(url)
    }
}

extension InboxTableViewController : RoverObserver {
    func didReceiveMessage(message: Message) {
        // Only add messages that have been marked to be saved
        guard message.savedToInbox else { return }
        unreadMessagesCount += 1
        // You may choose to add them to your CoreData model instead
        messages.insert(message, atIndex: 0)
        tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Automatic)
    }
}
