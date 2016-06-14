//
//  InboxTableViewController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-03-10.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import Rover
import SafariServices

class InboxTableViewController: UITableViewController {

    var messages = [Message]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(InboxTableViewController.reloadMessages), forControlEvents: .ValueChanged)
        
        reloadMessages()
        
        Rover.addObserver(self)
    }

    deinit {
        Rover.removeObserver(self)
    }
    
    func reloadMessages() {
        Rover.reloadInbox { messages in
            self.refreshControl?.endRefreshing()
            self.messages = messages
            self.tableView.reloadData()
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
        case .Link:
            guard let url = message.url else { break }
            let safariViewController = SFSafariViewController(URL: url)
            navigationController?.pushViewController(safariViewController, animated: true)
            break
        case .LandingPage:
            guard let screen = message.landingPage else { break }
            let screenViewController = RVScreenViewController(screen: screen)
            screenViewController.delegate = self
            navigationController?.pushViewController(screenViewController, animated: true)
        default:
            break
        }
    }

}

extension InboxTableViewController : RVScreenViewControllerDelegate {
    func screenViewController(viewController: RVScreenViewController, handleOpenURL url: NSURL) {
        let safariViewController = SFSafariViewController(URL: url)
        viewController.navigationController?.pushViewController(safariViewController, animated: true)
    }
}

extension InboxTableViewController : RoverObserver {
    func didDeliverMessage(message: Message) {
        // Only add messages that have been marked to be saved
        guard message.savedToInbox else { return }
        // You may choose to add them to your CoreData model instead
        messages.insert(message, atIndex: 0)
        tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Automatic)
    }
}
