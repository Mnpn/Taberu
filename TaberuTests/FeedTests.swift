//
//  FeedTests.swift
//  TaberuTests
//
//  Created by Martin Persson on 2023-09-21.
//

import XCTest
@testable import Taberu

final class FeedTests: XCTestCase {
    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    var bundle: Bundle?;

    override func setUpWithError() throws {
        bundle = Bundle(for: type(of: self))
    }

    override func tearDownWithError() throws { }

    func testFetchParsing() throws {
        // correct syntax
        let files = [("rss", "xml"), ("atom", "xml"), ("json", "json")]
        for feed in files {
            guard let path = bundle!.path(forResource: feed.0, ofType: feed.1) else {
                XCTAssert(false, "The \(feed.0) test file could not be located.")
                return
            }
            let rssFeed = appDelegate.fetch(url: URL(fileURLWithPath: path))
            XCTAssertNotNil(rssFeed?.entries[0].item.title, "Title is not present")
            XCTAssertTrue(rssFeed?.entries.count == 2, "Incorrect entry count")
        }
        // bad parameters / non-existent resource
        XCTAssertNil(appDelegate.fetch(url: URL(fileURLWithPath: "")), "Did not disregard a lacking URL")
    }

    func testHTMLRemoving() throws {
        let lotsOfHTML: String? = "<html><p><strong>なんでやね<br>ん</strong></p></html>"
        let fancy = lotsOfHTML.removeHTML(fancy: true)!
        let nonfancy = lotsOfHTML.removeHTML(fancy: false)!
        let nothing: String? = nil
        XCTAssertTrue(fancy == "なんでやね\nん", "Fancy HTML removal is wrong, expected 'なんでやね\nん', but got '\(fancy)'.".replacingOccurrences(of: "\n", with: "\\n"))
        XCTAssertTrue(nonfancy == "なんでやねん", "Non-fancy HTML removal is wrong, expected 'なんでやねん', but got '\(nonfancy)'.")
        XCTAssertTrue(nothing.removeHTML(fancy: true) == nothing, "HTML removal does not catch nil strings.")
    }
}
