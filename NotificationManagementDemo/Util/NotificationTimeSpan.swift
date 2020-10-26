//
//  NotificationTimeSpan.swift v.0.2.0
//  StickPlan
//
//  Created by Rudolf Farkas on 24.09.20.
//  Copyright © 2020 Eric PAJOT. All rights reserved.
//

import Foundation
import RudifaUtilPkg

extension Date {
    /// Return a dateTimeString with microsecond resolution
    var ddMMyyyy_HHmmss_𝜇s: String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond],
                                       from: self)
        let microSeconds = lrint(Double(comps.nanosecond!) / 1000) // Divide by 1000 and round

        let formatted = String(format: "%04ld-%02ld-%02ld %02ld:%02ld:%02ld.%06ld",
                               comps.year!, comps.month!, comps.day!,
                               comps.hour!, comps.minute!, comps.second!,
                               microSeconds)
        return formatted
    }
}

struct NotificationTimeSpan: Codable, Equatable {
    private(set) var title: String
    private(set) var message: String
    private(set) var start: Date
    private(set) var end: Date

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    /**
     observed on simulator and on iPhone:
     - Date() returns a value that is about 0.025 seconds after a full second
     - notification is delivered up to 0.7 s before the scheduled time
     - so, diff = now.timeIntervalSince(start) is rarely positive, mostly negative
     */
    var isCurrent: Bool {
        let now = Date()
        let isCurrent = start.incremented(by: .second, times: -2) <= now && now <= end
        return isCurrent
    }
}

extension NotificationTimeSpan {
    init(title: String, message: String, timeSpan: DateInterval) {
        self.title = title
        self.message = message
        start = timeSpan.start
        end = timeSpan.end
    }

    init?(from jsonString: String) {
        guard let this = Self.decode(from: jsonString) else { return nil }
        self = this
    }

    @available(*, unavailable, renamed: "jsonString")
    var string: String? {
        return encode()
    }

    var jsonString: String? {
        return encode()
    }
}

extension NotificationTimeSpan: CustomStringConvertible {
    var description: String {
        return "title= \(title), message= \(message), start= \(start.ddMMyyyy_HHmmss_𝜇s), end= \(end.ddMMyyyy_HHmmss_𝜇s)"
    }
}
