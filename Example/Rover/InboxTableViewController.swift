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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(InboxTableViewController.reloadMessages), forControlEvents: .ValueChanged)
        
        reloadMessages()
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
//        let message = messages[indexPath.row]
//        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
//        let markAction = UIAlertAction(title: message.read ? "Mark as unread" : "Mark as read", style: .Default) { action in
//            message.read = !message.read
//            Rover.patchMessage(message)
//            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
//        }
//        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
//        
//        alert.addAction(markAction)
//        alert.addAction(cancelAction)
//        
//        presentViewController(alert, animated: true) {
//            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
//        }
        let message = messages[indexPath.row]
        //Rover.followMessageAction(message)
        
        switch message.action {
        case .Link:
            break
        case .LandingPage:
            guard let screen = message.landingPage else { break }
            let screenViewController = RVScreenViewController(screen: screen)
            navigationController?.pushViewController(screenViewController, animated: true)
        default:
            break
        }
//        case .LandingPage:
//            let screenViewController = RVScreenViewController()
//            presentViewController(screenViewController, animated: true, completion: nil)
            
        //case .Experience:
        
    }

}
