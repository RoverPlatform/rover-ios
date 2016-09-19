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
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidOpen), name: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidOpen), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(InboxTableViewController.reloadMessages), for: .valueChanged)
        
        Rover.addObserver(self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageTableViewCellIdentifier", for: indexPath) as! MessageTableViewCell
        let message = messages[(indexPath as NSIndexPath).row]
        
        cell.titleLabel.text = message.title
        cell.messageTextLabel.text = message.text
        cell.unreadIndicatorView.isHidden = message.read
        
        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let message = messages[(indexPath as NSIndexPath).row]
            messages.remove(at: (indexPath as NSIndexPath).row)
            Rover.deleteMessage(message)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let message = messages[(indexPath as NSIndexPath).row]
        
        switch message.action {
        case .website:
            fallthrough
        case .deepLink:
            guard let url = message.url else { break }
            UIApplication.shared.openURL(url)
        case .landingPage:
            if let screenViewController = Rover.viewController(message: message) as? ScreenViewController {
                screenViewController.delegate = self
                navigationController?.pushViewController(screenViewController, animated: true)
            }
            break
        case .experience:
            if let experienceId = message.experienceId {
                let experienceViewController = ExperienceViewController(identifier: experienceId)
                present(experienceViewController, animated: true, completion: nil)
            }
        default:
            break
        }
        
        Rover.trackMessageOpenEvent(message)
        
        if (!message.read) {
            message.read = true
            self.unreadMessagesCount -= 1
            Rover.patchMessage(message)
            
            let cell = tableView.cellForRow(at: indexPath) as! MessageTableViewCell
            cell.unreadIndicatorView.isHidden = true
        }
    }
    
    // MARK: Application Observer
    
    func applicationDidOpen() {
        reloadMessages()
    }

}

extension InboxTableViewController : ScreenViewControllerDelegate {
    func screenViewController(_ viewController: ScreenViewController, handleOpenURL url: URL) {
        UIApplication.shared.openURL(url)
    }
}

extension InboxTableViewController : RoverObserver {
    func didReceiveMessage(_ message: Message) {
        // Only add messages that have been marked to be saved
        guard message.savedToInbox else { return }
        unreadMessagesCount += 1
        // You may choose to add them to your CoreData model instead
        messages.insert(message, at: 0)
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }
}
