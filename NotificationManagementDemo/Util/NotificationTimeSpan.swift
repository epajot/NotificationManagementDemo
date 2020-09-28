//
//  TimeSpanNotification.swift
//  StickPlan
//
//  Created by Rudolf Farkas on 24.09.20.
//  Copyright © 2020 Eric PAJOT. All rights reserved.
//

import Foundation

struct NotificationTimeSpan: Codable, Equatable {
    var title: String
    var message: String
    var start: Date
    var end: Date

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
    init(title: String, body: String, timeSpan: DateInterval) {
        self.title = title
        message = body
        start = timeSpan.start
        end = timeSpan.end
    }

    init?(from string: String) {
        guard let this = Self.decode(from: string) else { return nil }
        self = this
    }

    var string: String? {
        return encode()
    }
}
