//
//  TimeSpanNotificationTests.swift
//  StickPlanTests
//
//  Created by Rudolf Farkas on 24.09.20.
//  Copyright © 2020 Eric PAJOT. All rights reserved.
//

import XCTest

class TimeSpanNotificationTests: XCTestCase {
    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func test_TimeSpanNotification() {
        let calendar = Calendar.current
        let refDate = calendar.date(from: DateComponents(calendar: calendar, year: 2020, month: 1, day: 28, hour: 14))!
        let interval = DateInterval(start: refDate, duration: 7200)
        let tsNotification = TimeSpanNotification(title: "Title", message: "message", start: interval.start, end: interval.end)
        let identifier = tsNotification.string!
        XCTAssertEqual(identifier, #"{"message":"message","title":"Title","end":601916400,"start":601909200}"#)

        let tsNotification2 = TimeSpanNotification.decode(from: identifier)
        XCTAssertEqual(tsNotification, tsNotification2)
        XCTAssertFalse(tsNotification.isCurrent)
    }
}
