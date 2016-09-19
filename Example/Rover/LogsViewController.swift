//
//  LogsViewController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-04-25.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import Rover

class LogsViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    var liveLogs = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(LogsViewController.didReceiveLogReport(_:)), name: NSNotification.Name(rawValue: "RoverLogReportNotification"), object: nil)
    }

    @IBAction func didPressClear(_ sender: UIBarButtonItem) {
        liveLogs = ""
        textView.text = liveLogs
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {

    }
    
    func didReceiveLogReport(_ note: Notification) {
        guard let log = note.object as? String else { return }
        liveLogs = liveLogs + "\n" + log
        textView.text = liveLogs
    }
    
    @IBAction func didPressChangeServer(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: "Change Server", message: nil, preferredStyle: .alert)
        let action = UIAlertAction(title: "Change", style: .default) { (action) in
            UserDefaults.standard.set(alertController.textFields![0].text, forKey: "ROVER_SERVER_URL")
            Router.baseURLString = alertController.textFields![0].text!
        }
        alertController.addTextField { (textField) in
            textField.text = Router.baseURLString
        }
        alertController.addAction(action)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alertController, animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
