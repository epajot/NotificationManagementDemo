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
        //runForever()
    }

    /// Schedule a notification
    /// - Parameters:
    ///   - targetDate:
    ///   - identifier:
    func addNotification(at targetDate: Date, identifier: String) {
        if authorized {
            // set content
            let content = UNMutableNotificationContent()
            content.title = "Your booked period started"
            content.subtitle = ""
            content.body = ""
            content.categoryIdentifier = "message"
            content.badge = 1 // EP's Badge Test
            content.sound = UNNotificationSound.default // EP's Badge Test

            // set a calendar trigger
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: targetDate)
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
                    // DispatchQueue.main.async { self.updateCounts() }
                    self.updatePendingCount()
                }
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

    func updateBadge() {
        func dateFromString(str: String) -> Date? {
            let dateFormat = "dd.MM.yyyy HH:mm:ss"
            // "22.09.2020 16:50:26 to 22.09.2020 16:50:36"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = dateFormat
            dateFormatter.timeZone = TimeZone.current

            let date = dateFormatter.date(from: str)
            return date
        }

        func twoDateStringsFromString(str: String) -> [String] {
            let components = str.components(separatedBy: " to ")
            return components
        }

        func isCurrentBooking(string: String) -> Bool {
            let dateStrings = twoDateStringsFromString(str: string)
            if dateStrings.count == 2 {
                let dates = dateStrings.map { dateFromString(str: $0) }

                if let start = dates[0], let end = dates[1] {
                    print("  dates: \(start.ddMMyyyy_HHmmss) \(end.ddMMyyyy_HHmmss)")

                    let now = Date()
                    let isCurrentBooking = start <= now && now <= end
                    return isCurrentBooking
                }
            }
            return false
        }

        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            self.printClassAndFunc(info: "Delivered  \(notifications.count)")
//            for notification: UNNotification in notifications {
//                let identifier = notification.request.identifier
//                print("  id: \(identifier) \(isCurrentBooking(string: identifier))")
//            }

            let currentBookings = notifications.filter { isCurrentBooking(string: $0.request.identifier) }
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = currentBookings.count
            }
            self.printClassAndFunc(info: "Delivered: \(notifications.count) current: \(currentBookings.count)")
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
            //            DispatchQueue.main.async {
            //                UIApplication.shared.applicationIconBadgeNumber = requests.count
            //            }
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
            //            DispatchQueue.main.async {
            //                UIApplication.shared.applicationIconBadgeNumber = notifications.count
            //            }
        }
    }

    private func updateBothCounts() {
        updatePendingCount()
        updateDeliveredCount()
    }

    func runForever() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            self.updateBadge()
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // MARK: feedback when app is running

    // The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.

    internal func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        printClassAndFunc()
        updateBothCounts()
//        updateBadge()
        completionHandler([.alert, .badge, .sound])
    }

    // The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:.

    internal func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        printClassAndFunc(info: "\(response.notification.request.identifier)")
        completionHandler()
    }
}
