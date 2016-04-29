//
//  LogsViewController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-04-25.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

class LogsViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    var liveLogs = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(LogsViewController.didReceiveLogReport(_:)), name: "RoverLogReportNotification", object: nil)
    }

    @IBAction func didPressClear(sender: UIBarButtonItem) {
        liveLogs = ""
        textView.text = liveLogs
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    @IBAction func segmentChanged(sender: UISegmentedControl) {

    }
    
    func didReceiveLogReport(note: NSNotification) {
        guard let log = note.object as? String else { return }
        liveLogs = liveLogs + "\n" + log
        textView.text = liveLogs
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
