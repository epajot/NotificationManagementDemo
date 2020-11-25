//
//  NotificationManager.swift v.0.3.0
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

/// MARK: NotificationManager

class NotificationManager: NSObject {
    // MARK: private vars

    private let center = UNUserNotificationCenter.current()

    private(set) var authorized = false

    private var notificationTimeSpansReceived: [NotificationTimeSpan] = []

    // MARK: public API

    static let shared = NotificationManager()

    /// The controller interested in counts shall set a callback here
    var updateClientDiagnosticCounts: ((NotificationCounts) -> Void)? {
        didSet {
            updateBadgeAndCounts()
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
        // Create the request and schedule it
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.printClassAndFunc(info: "\(String(describing: error))")
            } else {
                self.updateBadgeAndCounts()
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
        // executes asynchronously; provides no callback to report completion
        center.removePendingNotificationRequests(withIdentifiers: [id])
        // this launches query for pending notifications, there might be a race
        updateBadgeAndCounts()
    }

    /// Remove all pending notification requests
    func removeAllPendingNotificationRequests() {
        center.removeAllPendingNotificationRequests()
    }

    /// Clear the list of delivered notifications
    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
        printClassAndFunc()
        updateBadgeAndCounts()
    }

    /// Clear the badge
    func clearBadge() {
        printClassAndFunc()
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    private func getReceivedNotificationCounts() -> NotificationCounts {
        let timeSpansCurrent = notificationTimeSpansReceived.filter{ $0.isCurrent }
        return NotificationCounts(pending: 0, delivered: 0, current: timeSpansCurrent.count)
    }

    func updateBadgeAndCounts() {
        var diagnosticCounts = getReceivedNotificationCounts()

        func current(in identifiers: [String]) -> [String] {
            return identifiers.filter({ (NotificationTimeSpan(from: $0)?.isCurrent ?? false) })
        }

        func obsolete(in identifiers: [String]) -> [String] {
            return identifiers.filter({ !(NotificationTimeSpan(from: $0)?.isCurrent ?? true) })
        }

        func notifications(_ delivered: [UNNotification]) {
            let identifiers = delivered.map({ $0.request.identifier })
            let currentIdentifiers = current(in: identifiers)
            let obsoleteIdentifiers = obsolete(in: identifiers)

            diagnosticCounts.delivered = delivered.count
            diagnosticCounts.current += currentIdentifiers.count

            // update badge count to the number of current notifications
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = diagnosticCounts.current
            }

            // remove obsolete notifications
            center.removeDeliveredNotifications(withIdentifiers: obsoleteIdentifiers)


            center.getPendingNotificationRequests { pendingRequests in
                diagnosticCounts.pending = pendingRequests.count
                self.printClassAndFunc(info: "@\(diagnosticCounts)")
                self.updateClientDiagnosticCounts?(diagnosticCounts)
            }
        }

        UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: notifications)
    }
}

// MARK: Delegate callbacks (from NotificationCenter)

extension NotificationManager: UNUserNotificationCenterDelegate {
    // MARK: feedback when app is running

    // The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.

    internal func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        printClassAndFunc(info: "@isEndOfBooking= \(notification.isEndOfBooking)")

        if notification.isEndOfBooking {
            completionHandler([])
            center.removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
        } else {
            completionHandler([.alert, .badge, .sound])
            addNotificationAtEndOf(oldNotification: notification)
        }

        updateBadgeAndCounts()
    }

    // The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:.

    internal func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        if let timeSpan = NotificationTimeSpan(from: identifier) {
            notificationTimeSpansReceived.append(timeSpan)
        }
        completionHandler()
        printClassAndFunc(info: "@ identifier= \(identifier), received count= \(notificationTimeSpansReceived.count)")
    }
}
