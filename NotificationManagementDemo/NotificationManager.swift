//
//  NotificationManager.swift
//  StickPlan
//
//  Created by Eric PAJOT on 11.09.20.
//  Copyright © 2020 Eric PAJOT. All rights reserved.
//

import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private(set) var authorized = false

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                self.authorized = true
                print("Notifications Accepted")
            } else {
                print("Notifications not Accepted")
            }
        }
    }

    func scheduleNotification(date: Date, title: String, body: String) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.badge = 1
        content.title = title
        content.body = body
        content.categoryIdentifier = "alarm"
        content.userInfo = [:]
        content.sound = UNNotificationSound.default

//        let nextTriggerDate = Date()

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
//        print(trigger.nextTriggerDate())

//        dateComponents.hour = 16
//        dateComponents.minute = 15
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
//        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request)
    }

//    // EP's Test - WIP
//    func getPendingNotificationRequests(completionHandler: @escaping ([UNNotificationRequest]) -> Void) {
//        let center = UNUserNotificationCenter.current()
//        center.printClassAndFunc(info: <#T##String#>)
//    }
//
//    // EP's Test - WIP
//    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
//        let center = UNUserNotificationCenter.current()
//    }
}
