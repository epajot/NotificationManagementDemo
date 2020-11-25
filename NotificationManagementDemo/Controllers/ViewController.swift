//
//  ViewController.swift v.0.2.0
//  NotificationManagementDemo
//
//  Created by Steven Lipton on 11/18/16.
//  Copyright © 2016 Steven Lipton. All rights reserved.
//

import RudifaUtilPkg
import UIKit

struct Booking {
    var interval: DateInterval
    var id: String {
        interval.brief
    }
}

enum Mode {
    case singleBooking
    case twoSimultaneousBookings
    case twoBookingsFollowingEachOther
}

class ViewController: UIViewController {
    // MARK: variables

    var bookings: [Booking] = []

    // var isGrantedNotificationAccess = false

    @IBOutlet var countsLabel: UILabel!

    @IBOutlet var tableView: UITableView!

    @IBOutlet var addBookingButton: UIButton!

    var startAfterSeconds = 10 { didSet { updateAddBookingButtonText() } }

    var durationSeconds = 10 { didSet { updateAddBookingButtonText() } }

    // MARK: startup

    override func viewDidLoad() {
        super.viewDidLoad()
        printClassAndFunc()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        updateAddBookingButtonText()

        // initialize the callback to receive the counts
        NotificationManager.shared.updateClientDiagnosticCounts = updateCountsLabel
    }

    // MARK: UI interactions

    @IBAction func stepperStartChanged(_ sender: UIStepper) {
        startAfterSeconds = Int(sender.value)
    }

    @IBAction func stepperDurationChanged(_ sender: UIStepper) {
        durationSeconds = Int(sender.value)
    }

    @IBAction func addBooking(_: Any) {
        let start = Date().incremented(by: .second, times: startAfterSeconds)
        let end = start.incremented(by: .second, times: durationSeconds)
        let end2 = end.incremented(by: .second, times: durationSeconds)
        let booking1 = Booking(interval: DateInterval(start: start, end: end))
        bookings.append(booking1)

        let title = "SomeCalendar"
        let body = "Your booking starts now"
        NotificationManager.shared.addNotification(title: title, message: body, for: booking1.interval)

        var mode = Mode.twoBookingsFollowingEachOther

        switch (mode) {
        case .singleBooking:
            break
        case .twoSimultaneousBookings:
            let booking2 = Booking(interval: DateInterval(start: start, end: end))
            bookings.append(booking2)
            NotificationManager.shared.addNotification(title: title, message: body, for: booking2.interval)
            break
        case .twoBookingsFollowingEachOther:
            let booking2 = Booking(interval: DateInterval(start: end, end: end2))
            bookings.append(booking2)
            NotificationManager.shared.addNotification(title: title, message: body, for: booking2.interval)
            break
        }

        tableView.reloadData()
    }

    @IBAction func removeAll(_: UIButton) {
        NotificationManager.shared.removeAllPendingNotificationRequests()
        NotificationManager.shared.removeAllDeliveredNotifications() // calls indirectly updateCountsLabel()
        bookings = []
        tableView.reloadData()
    }

    func updateAddBookingButtonText() {
        addBookingButton.setTitle("Add Booking in \(startAfterSeconds) s for \(durationSeconds) s", for: .normal)
    }

    func updateCountsLabel(counts: NotificationCounts) {
        DispatchQueue.main.async {
            self.countsLabel.text = counts.description
        }
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
                let removedBooking = self.bookings.remove(at: indexPath.row)
                self.tableView.reloadData()
                NotificationManager.shared.removePendingNotificationRequests(with: removedBooking.id)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .default) { _ in print("Cancel") })
            present(alert, animated: true)
        }

        presentAlert(title: "Remove booking?", message: "")
    }
}
