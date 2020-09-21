//
//  ViewController.swift
//  NotificationManagementDemo
//
//  Created by Steven Lipton on 11/18/16.
//  Copyright © 2016 Steven Lipton. All rights reserved.
//

import UIKit
import UserNotifications

class ViewController: UIViewController, UNUserNotificationCenterDelegate {
    var isGrantedNotificationAccess = false
    
    @IBAction func setNotification(_ sender: UIButton) {
        if isGrantedNotificationAccess {
//            let center = UNUserNotificationCenter.current() // EP's Badge Test
//            //set content
            let content = UNMutableNotificationContent()
            content.title = "My Notification Management Demo"
            content.subtitle = "Timed Notification"
            content.body = "Notification pressed"
            content.categoryIdentifier = "message"
            content.badge = 1 // EP's Badge Test
            content.sound = UNNotificationSound.default // EP's Badge Test
            
            // set trigger
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: 5,
                repeats: false)
            
            // Create the request
            let request = UNNotificationRequest(
                identifier: "\(Date())", // EP's Badge Test
                content: content,
                trigger: trigger)
            
            UNUserNotificationCenter.current().delegate = self
            
//            center.add(request)
            
            // Schedule the request
            UNUserNotificationCenter.current().add(
                request, withCompletionHandler: nil)
        }
        printClassAndFunc()
    }
    
    @IBAction func listPendingNotification(_ sender: UIButton) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("Pending Notification Count \(requests.count)")
//            print("Pending Notification List \(requests)")
        }
    }
    
    @IBAction func listNotification(_ sender: UIButton) {
        UNUserNotificationCenter.current().getDeliveredNotifications { requests in
            print("Delivered Notification Count \(requests.count)")
            UIApplication.shared.applicationIconBadgeNumber = requests.count
//            print("Delivered Notification List \(requests)")
        }
    }
    
    @IBAction func removeNotification(_ sender: UIButton) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
        print("Delivered Notification List & Badge Clear..")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge],
            completionHandler: { granted, _ in
                self.isGrantedNotificationAccess = granted
                if !granted {
                    // add alert to complain
                }
        })
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // displaying the ios local notification when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
}
