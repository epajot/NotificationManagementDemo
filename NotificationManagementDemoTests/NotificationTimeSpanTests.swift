//
//  NotificationTimeSpanTests.swift v.0.2.0
//  StickPlanTests
//
//  Created by Rudolf Farkas on 24.09.20.
//  Copyright © 2020 Eric PAJOT. All rights reserved.
//

import XCTest

class NotificationTimeSpanTests: XCTestCase {
    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func test_NotificationTimeSpan() {
        let calendar = Calendar.current
        let refDate = calendar.date(from: DateComponents(calendar: calendar, year: 2020, month: 1, day: 28, hour: 14))!
        let interval = DateInterval(start: refDate, duration: 7200)
        let tsNotification = NotificationTimeSpan(title: "Title", message: "message", start: interval.start, end: interval.end)
        let identifier = tsNotification.string!
        XCTAssertEqual(identifier, #"{"message":"message","title":"Title","end":601916400,"start":601909200}"#)

        let tsNotification2 = NotificationTimeSpan.decode(from: identifier)
        XCTAssertEqual(tsNotification, tsNotification2)
        XCTAssertFalse(tsNotification.isCurrent)
    }
}
