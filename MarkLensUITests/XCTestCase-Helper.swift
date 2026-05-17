//
//  XCTestCase-Helper.swift
//  TeacherToolUITests
//
//  Created by Philipp on 08.05.2026.
//

import XCTest

extension XCTestCase {
    func capture(_ app: XCUIApplication, name: String, file: StaticString = #file, line: UInt = #line) {
        let screenshot = app.screenshot()
        add(screenshot, name: name)
    }

    func capture(_ element: XCUIElement, name: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.exists, "Cannot capture a screenshot for a missing element.", file: file, line: line)
        let screenshot = element.screenshot()
        add(screenshot, name: name)
    }

    private func add(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
