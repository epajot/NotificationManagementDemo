//
//  NotificationManager.swift
//  StickPlan
//
//  Created by Eric PAJOT on 11.09.20.
//  Copyright © 2020 Eric PAJOT. All rights reserved.
//

import UIKit
import UserNotifications

struct NotificationCounts {
    var pending: Int
    var delivered: Int
}

class NotificationManager: NSObject {
    // MARK: private vars

    private let currentCenter = UNUserNotificationCenter.current()

    private(set) var authorized = false

    private var notificationCounts = NotificationCounts(pending: 0, delivered: 0)

    // MARK: public API

    static let shared = NotificationManager()

    /// The controller interested in counts shall provide a callback
    var updateDiagnosticCounts: ((NotificationCounts) -> Void)? {
        didSet { updateBothCounts() }
    }

    /// Connect to UNUserNotificationCenter and get authorization from user
    func initializeAtAppStart() {
        currentCenter.delegate = self
        currentCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                self.authorized = true
            }
            self.printClassAndFunc(info: granted ? "Notifications allowed" : "Notifications NOT allowed")
        }
        // runForever() // experimental
    }

    /// Schedule a notification
    /// - Parameters:
    ///   - title: for notification alert
    ///   - body: text for notification alert
    ///   - interval: the associated time period where interval.start is the notifucation trigger time
    func addNotification(title: String, body: String, for interval: DateInterval) {
        if !authorized {
            return
        }

        guard let identifier = NotificationTimeSpan(title: title, body: body, timeSpan: interval).string else {
            return
        }

        // set content
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = ""
        content.body = body
        content.categoryIdentifier = "alarm"
        content.badge = 1
        content.sound = UNNotificationSound.default
        content.userInfo = [:]

        // set a calendar trigger
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: interval.start)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        // Create the request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Schedule the request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.printClassAndFunc(info: "\(String(describing: error))")
            } else {
                self.updatePendingCount()
            }
        }
    }

    /// Remove a pending notificaton
    /// - Parameter id: target notification id
    func removeNotificationRequest(with id: String) {
        // executes asynchronously, has no callback to report completion
        currentCenter.removePendingNotificationRequests(withIdentifiers: [id])
        // this launches query for pending notifications, there might be a race
        updatePendingCount()
    }

    /// Clear the list of delivered notifications
    func removeAllDeliveredNotifications() {
        currentCenter.removeAllDeliveredNotifications()
        printClassAndFunc()
        updateDeliveredCount()
    }

    /// Clear the badge
    func clearBadge() {
        printClassAndFunc()
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func updateBadgeAndCounts() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in

            // update badge count to the number of current notifications

            let currentNotifications = notifications.filter { (NotificationTimeSpan(from: $0.request.identifier)?.isCurrent ?? false) }
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = currentNotifications.count
            }

            // remove obsolete (not current) notifications

            let identifiers = notifications.map({ $0.request.identifier })
            let identifiersNotCurrent = identifiers.filter({ !(NotificationTimeSpan(from: $0)?.isCurrent ?? true) })
            self.currentCenter.removeDeliveredNotifications(withIdentifiers: identifiersNotCurrent)

            self.printClassAndFunc(info: "delivered: \(notifications.count) current: \(currentNotifications.count)")
        }
    }

    // MARK: count query helpers

    private func updatePendingCount() {
        currentCenter.getPendingNotificationRequests { requests in
            self.printClassAndFunc(info: "Pending  \(requests.count)")
            for request in requests {
                print("  id: \(request.identifier)")
            }
            self.notificationCounts.pending = requests.count
            self.updateDiagnosticCounts?(self.notificationCounts)
            // this can be uncommented to prove that the bandge number can be modified this way
            //  DispatchQueue.main.async {
            //      UIApplication.shared.applicationIconBadgeNumber = requests.count
            //  }
        }
    }

    private func updateDeliveredCount() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            self.printClassAndFunc(info: "Delivered  \(notifications.count)")
            for notification: UNNotification in notifications {
                print("  id: \(notification.request.identifier)")
            }
            self.notificationCounts.delivered = notifications.count
            self.updateDiagnosticCounts?(self.notificationCounts)
            // this is next to useless because there is no callback when a notification is delivered while app is in background
            // DispatchQueue.main.async {
            //     UIApplication.shared.applicationIconBadgeNumber = notifications.count
            // }
        }
    }

    private func updateBothCounts() {
        updatePendingCount()
        updateDeliveredCount()
    }

//    func runForever() {
//        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
//            self.updateBadgeAndCounts()
//        }
//    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // MARK: feedback when app is running

    // The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.

    internal func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        printClassAndFunc()
        updateBothCounts()
        updateBadgeAndCounts()
        completionHandler([.alert, .badge, .sound])
    }

    // The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:.

    internal func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        printClassAndFunc(info: "\(response.notification.request.identifier)")
        completionHandler()
    }
}
