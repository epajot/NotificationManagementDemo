//
//  NotificationManager.swift v.0.2.0
//  StickPlan
//
//  Created by Eric PAJOT on 11.09.20.
//  Copyright © 2020 Eric PAJOT. All rights reserved.
//

import UIKit
import UserNotifications

extension UNMutableNotificationContent {
    convenience init(from other: UNNotificationContent) {
        self.init()
        title = other.title
        subtitle = other.subtitle
        body = other.body
        categoryIdentifier = other.categoryIdentifier
        badge = nil
        sound = nil
        userInfo = ["end-of-booking": true]
    }
}

extension UNNotification {
    var isEndOfBooking: Bool {
        request.content.userInfo["end-of-booking"] != nil
    }
}

struct NotificationCounts: CustomStringConvertible {
    var pending: Int
    var delivered: Int
    var current: Int

    @available(*, unavailable, renamed: "description")
    var string: String {
        return "pending: \(pending), delivered: \(delivered), current: \(current)"
    }

    var description: String {
        return "pending: \(pending), delivered: \(delivered), current: \(current)"
    }
}

extension UNCalendarNotificationTrigger {
    /// Innitialize an instance to trigger on the date, with seconds resolution
    /// - Parameters:
    ///   - dateWithSecondsResolution: target date
    ///   - repeats: as required
    convenience init(dateWithSecondsResolution: Date, repeats: Bool) {
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dateWithSecondsResolution)
        self.init(dateMatching: dateComponents, repeats: false)
    }
}

class NotificationManager: NSObject {
    // MARK: private vars

    private let center = UNUserNotificationCenter.current()

    private(set) var authorized = false

    // MARK: public API

    static let shared = NotificationManager()

    /// The controller interested in counts shall set a callback here
    var updateClientDiagnosticCounts: ((NotificationCounts) -> Void)? {
        didSet {
            retrieveDiagnosticCounts()
        }
    }

    /// Connect to UNUserNotificationCenter and get authorization from user
    func initializeAtAppStart() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                self.authorized = true
            }
            self.printClassAndFunc(info: granted ? "Notifications allowed" : "Notifications NOT allowed")
        }
    }

    private func addNotificationRequest(_ identifier: String, _ content: UNMutableNotificationContent, _ trigger: UNCalendarNotificationTrigger) {
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
                self.retrieveDiagnosticCounts()
            }
        }
    }

    /// Schedule a notification
    /// - Parameters:
    ///   - title: for notification alert
    ///   - body: text for notification alert
    ///   - interval: the associated time period where interval.start is the notifucation trigger time
    func addNotification(title: String, message: String, for interval: DateInterval) {
        if !authorized {
            return
        }

        let notificationTimeSpan = NotificationTimeSpan(title: title, message: message, timeSpan: interval)
        printClassAndFunc(info: "@\(notificationTimeSpan)")

        guard let identifier = notificationTimeSpan.jsonString else { return }

        // set content
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = ""
        content.body = message
        content.categoryIdentifier = "alarm"
        content.badge = 1
        content.sound = UNNotificationSound.default
        content.userInfo = [:]

        // set a calendar trigger
        let trigger = UNCalendarNotificationTrigger(dateWithSecondsResolution: interval.start, repeats: false)

        addNotificationRequest(identifier, content, trigger)
    }

    /// Schedule a notification

    /// Add a request with the same identifier, trigger at the interval.end and userInfo = ["endOfBooking": true]
    /// - Parameter oldNotification: received notification
    func addNotificationAtEndOf(oldNotification: UNNotification) {
        if !authorized {
            return
        }

        let identifier = oldNotification.request.identifier

        guard let notificationTS = NotificationTimeSpan(from: identifier) else {
            printClassAndFunc(info: "*** failed to get NotificationTimeSpan from \(identifier)")
            return
        }

        let content = UNMutableNotificationContent(from: oldNotification.request.content)

        // set a calendar trigger
        let trigger = UNCalendarNotificationTrigger(dateWithSecondsResolution: notificationTS.end, repeats: false)

        addNotificationRequest(identifier, content, trigger)
    }

    /// Remove a pending notificaton
    /// - Parameter id: target notification id
    func removePendingNotificationRequests(with id: String) {
        printClassAndFunc(info: id)
        // executes asynchronously, has no callback to report completion
        center.removePendingNotificationRequests(withIdentifiers: [id])
        // this launches query for pending notifications, there might be a race
        retrieveDiagnosticCounts()
    }

    /// Clear the list of delivered notifications
    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
        printClassAndFunc()
        retrieveDiagnosticCounts()
    }

    /// Clear the badge
    func clearBadge() {
        printClassAndFunc()
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func updateBadgeAndCounts() {
        UNUserNotificationCenter.current().getDeliveredNotifications { deliveredNotifications in

            // update badge count to the number of current notifications

            let currentNotifications = deliveredNotifications.filter { (NotificationTimeSpan(from: $0.request.identifier)?.isCurrent ?? false) }
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = currentNotifications.count
            }

            // remove obsolete (not current) notifications

            let identifiers = deliveredNotifications.map({ $0.request.identifier })
            let identifiersNotCurrent = identifiers.filter({ !(NotificationTimeSpan(from: $0)?.isCurrent ?? true) })
            self.center.removeDeliveredNotifications(withIdentifiers: identifiersNotCurrent)
            self.printClassAndFunc(info: "@delivered: \(deliveredNotifications.count) current: \(currentNotifications.count)")
        }
    }

    // MARK: count query helpers

    /// Return identifiers belonging to current notifications
    /// - Parameter notifications: array to filter
    /// - Returns: filtered array
    private func identifiersCurrent(in notifications: [UNNotification]) -> [String] {
        let identifiers = notifications.map({ $0.request.identifier })
        return identifiers.filter({ (NotificationTimeSpan(from: $0)?.isCurrent ?? false) })
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // MARK: feedback when app is running

    // The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.

    internal func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        printClassAndFunc(info: "@ userInfo= \(notification.request.content.userInfo), isEndOfBooking= \(notification.isEndOfBooking)")

        if notification.isEndOfBooking {
            completionHandler([])
            center.removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
        } else {
            completionHandler([.alert, .badge, .sound])
            addNotificationAtEndOf(oldNotification: notification)
        }

        retrieveDiagnosticCounts()
        updateBadgeAndCounts()
    }

    // The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:.

    internal func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        printClassAndFunc(info: "\(response.notification.request.identifier)")
        completionHandler()
    }
}

// MARK: dispatch group

extension NotificationManager {
    // Using DispatchGroup to execute two asynchronous operations and then handle the results
    func retrieveDiagnosticCounts() {
        let dispatchGroup = DispatchGroup()
        var diagnosticCounts = NotificationCounts(pending: -1, delivered: -1, current: -1)

        dispatchGroup.enter()
        center.getPendingNotificationRequests { pendingRequests in
            self.printClassAndFunc(info: "@Pending  \(pendingRequests.count)")
            for request in pendingRequests {
                self.printClassAndFunc(info: "@pendingRequests: \(NotificationTimeSpan(from: request.identifier)!)")
            }
            diagnosticCounts.pending = pendingRequests.count
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        center.getDeliveredNotifications { deliveredNotifications in
            self.printClassAndFunc(info: "@Delivered  \(deliveredNotifications.count)")
            for notification in deliveredNotifications {
                if let ntSpan = NotificationTimeSpan(from: notification.request.identifier) {
                    self.printClassAndFunc(info: "@deliveredNotifications: \(ntSpan)")
                }
            }
            diagnosticCounts.delivered = deliveredNotifications.count
            diagnosticCounts.current = self.identifiersCurrent(in: deliveredNotifications).count
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.printClassAndFunc(info: "@\(diagnosticCounts)")
            DispatchQueue.main.async {
                self?.updateClientDiagnosticCounts?(diagnosticCounts)
            }
        }
    }
}
