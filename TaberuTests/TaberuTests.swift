//
//  TaberuTests.swift
//  TaberuTests
//
//  Created by Martin Persson on 2023-09-21.
//

import XCTest
@testable import Taberu

final class TaberuTests: XCTestCase {
    let appDelegate = NSApplication.shared.delegate as! AppDelegate

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTimerRemaining() throws {
        let expectations = [(75.0, "01:15"), (3760, "01:02:40"), (-100, "00:00"), (0, "00:00")]
        for expectation in expectations {
            let exampleTimer = Timer.scheduledTimer(withTimeInterval: expectation.0, repeats: true) {timer in}
            let timeRemaining = appDelegate.getTimerRemaining(exampleTimer)
            XCTAssertTrue(timeRemaining == expectation.1, "Timer remaining calculation is incorrect, expected '\(expectation.1)', got '\(timeRemaining)'.")
        }
        let bogusTimerRemaining = appDelegate.getTimerRemaining(Timer())
        XCTAssertTrue(bogusTimerRemaining == "??", "Timer remaining handling is incorrect, expected '??', got '\(bogusTimerRemaining)'.")
    }
}
