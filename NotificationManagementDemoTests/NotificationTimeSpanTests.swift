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
        // create a test DateInterval
        let testDate = Date(timeIntervalSinceReferenceDate: 625_329_725.286_747)
        let testInterval = DateInterval(start: testDate, duration: 7200)
        XCTAssertEqual(testDate.ddMMyyyy_HHmmss_𝜇s, "2020-10-25 15:42:05.286747")

        // create a NotificationTimeSpan and a notification identifier
        let testSpan = NotificationTimeSpan(title: "SomeResource", message: "booked", timeSpan: testInterval)
        XCTAssertEqual(testSpan.description, "title= SomeResource, message= booked, start= 2020-10-25 15:42:05.286747, end= 2020-10-25 17:42:05.286747")
        XCTAssertEqual("\(testSpan)", "title= SomeResource, message= booked, start= 2020-10-25 15:42:05.286747, end= 2020-10-25 17:42:05.286747")
        XCTAssertEqual("\(testSpan.interval)", "2020-10-25 14:42:05 +0000 to 2020-10-25 16:42:05 +0000")

        guard let testIdentifier = testSpan.jsonString else { XCTFail(); return }
        XCTAssertEqual(testIdentifier, #"{"message":"booked","title":"SomeResource","end":625336925.28674698,"start":625329725.28674698}"#)
//        XCTAssertEqual failed: ("{"title":"SomeResource","message":"booked","interval":{"start":625329725.28674698,"duration":7200}}") is not equal to ("{"message":"booked","title":"SomeResource","end":625336925.28674698,"start":625329725.28674698}")
        // recover a NotificationTimeSpan from the identifier and compare with the original
        let testSpan2 = NotificationTimeSpan(from: testIdentifier)
        XCTAssertEqual(testSpan, testSpan2)
        XCTAssertFalse(testSpan.isCurrent)
    }

    func test_NotificationCounts() {
        let testCounts = NotificationCounts(pending: 1, delivered: 7, current: 2)
        XCTAssertEqual(testCounts.description, "pending: 1, delivered: 7, current: 2")
        XCTAssertEqual("\(testCounts)", "pending: 1, delivered: 7, current: 2")
    }
}
