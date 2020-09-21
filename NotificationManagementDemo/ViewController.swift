//
//  ViewController.swift
//  NotificationManagementDemo
//
//  Created by Steven Lipton on 11/18/16.
//  Copyright © 2016 Steven Lipton. All rights reserved.
//

import UIKit
import UserNotifications

struct Booking {
    var interval: DateInterval
    var id: String {
        interval.brief
    }
}

class ViewController: UIViewController {
    // MARK: variables

    var bookings: [Booking] = []

    var isGrantedNotificationAccess = false

    @IBOutlet var countsLabel: UILabel!

    @IBOutlet var tableView: UITableView!

    @IBOutlet var addBookingButton: UIButton!

    var countPending = 0 { didSet { updateCountsLabel() } }

    var countDelivered = 0 { didSet { updateCountsLabel() } }

    var startAfterSeconds = 10 { didSet { updateAddBookingButtonText() } }

    var durationSeconds = 10 { didSet { updateAddBookingButtonText() } }

    // MARK: startup

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        updateAddBookingButtonText()
        updateCounts()

        /* TODO:
         You must assign your delegate object to the UNUserNotificationCenter object before your app finishes launching. For example, in an iOS app, you must assign it in the application(_:willFinishLaunchingWithOptions:) or application(_:didFinishLaunchingWithOptions:) method of your app delegate. Assigning a delegate after these methods are called might cause you to miss incoming notifications.
         */
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            self.isGrantedNotificationAccess = granted
            if !granted {
                // add alert to complain
            }
        }
    }

    // MARK: UI interactions

    @IBAction func stepperStartChanged(_ sender: UIStepper) {
        startAfterSeconds = Int(sender.value)
    }

    @IBAction func stepperDurationChanged(_ sender: UIStepper) {
        durationSeconds = Int(sender.value)
    }

    @IBAction func addBooking(_: Any) {
        let booking = Booking(interval: DateInterval(start: Date().incremented(by: .second, times: startAfterSeconds), duration: TimeInterval(durationSeconds)))
        bookings.append(booking)
        tableView.reloadData()
        requestNotification(at: booking.interval.start, identifier: booking.id)
    }

    func updateAddBookingButtonText() {
        addBookingButton.setTitle("Add Booking in \(startAfterSeconds) s for \(durationSeconds) s", for: .normal)
    }

    func updateCountsLabel() {
        countsLabel.text = "pending: \(countPending), delivered: \(countDelivered)"
    }

    @IBAction func setNotification(_: UIButton) {
        requestNotification(at: Date(), identifier: "\(Date())")
    }

    func requestNotification(at targetDate: Date, identifier: String) {
        if isGrantedNotificationAccess {
            //            let center = UNUserNotificationCenter.current() // EP's Badge Test
            // set content
            let content = UNMutableNotificationContent()
            content.title = "Your booked period started"
            content.subtitle = ""
            content.body = ""
            content.categoryIdentifier = "message"
            content.badge = 1 // EP's Badge Test
            content.sound = UNNotificationSound.default // EP's Badge Test

            // set trigger
            let timeInterval = DateInterval(start: Date(), end: targetDate).duration
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)

            // TODO: this did not seem to work, why?
//            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
//            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

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
                    DispatchQueue.main.async { self.updateCounts() }
                }
            }
        }
    }

    func updateCounts() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("Pending  \(requests.count)")
            for request in requests {
                print("  id: \(request.identifier)")
            }
            DispatchQueue.main.async {
                self.countPending = requests.count
            }
        }
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            print("Delivered  \(notifications.count)")

            for notification: UNNotification in notifications {
                print("  id: \(notification.request.identifier)")
            }
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = notifications.count
                self.countDelivered = notifications.count
            }
        }
    }

    func removeNotificationRequest(with id: String) {
        // executes asynchronously, has no callback to report completion
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        // this launches queries for pending ans delivered notifications, there might be a race
        updateCounts()
    }

    @IBAction func removeAllDeliveredNotifications(_: UIButton) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
        printClassAndFunc()
        updateCounts()
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!

        let booking = bookings[indexPath.row]
        let text = "id: \(booking.id) "

        cell.textLabel?.text = text
        cell.textLabel?.adjustsFontSizeToFitWidth = true

        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        func presentAlert(title: String, message: String) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                print("OK")
                let removedBooking = self.bookings.remove(at: indexPath.row)
                self.tableView.reloadData()
                self.removeNotificationRequest(with: removedBooking.id)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .default) { _ in print("Cancel") })
            present(alert, animated: true)
        }

        presentAlert(title: "Remove booking?", message: "")
    }
}

extension ViewController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // displaying the ios local notification when app is in foreground
        printClassAndFunc()
        updateCounts()
        completionHandler([.alert, .badge, .sound])
    }
}
