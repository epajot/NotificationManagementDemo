//
//  ViewController.swift
//  NotificationManagementDemo
//
//  Created by Steven Lipton on 11/18/16.
//  Copyright © 2016 Steven Lipton. All rights reserved.
//

import UIKit
import UserNotifications

class ViewController: UIViewController {
    var isGrantedNotificationAccess = false

    @IBAction func setNotification(_ sender: UIButton) {
        if isGrantedNotificationAccess{
            //set content
            let content = UNMutableNotificationContent()
            content.title = "My Notification Management Demo"
            content.subtitle = "Timed Notification"
            content.body = "Notification pressed"
            content.categoryIdentifier = "message"
            
            //set trigger
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: 10.0,
                repeats: false)
            
            //Create the request
            let request = UNNotificationRequest(
                identifier: "my.notification",
                content: content,
                trigger: trigger
            )
            //Schedule the request
            UNUserNotificationCenter.current().add(
                request, withCompletionHandler: nil)
        }
    }
    
    @IBAction func listNotification(_ sender: UIButton) {
    }

    @IBAction func removeNotification(_ sender: UIButton) {
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert,.sound,.badge],
            completionHandler: { (granted,error) in
                self.isGrantedNotificationAccess = granted
                if !granted{
                    //add alert to complain
                }
        })
    }
}

