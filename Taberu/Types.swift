//
//  Types.swift
//  Taberu
//
//  Created by Martin Persson on 2023-01-26.
//

import FeedKit
import Foundation

class Entry {
    let item: RSSFeedItem
    let parent: Feed
    let id: Int
    var unread: Bool = true
    var notified: Bool = false

    init(item: RSSFeedItem, parent: Feed, id: Int) {
        self.item = item
        self.parent = parent
        self.id = id
    }
}

class Feed {
    let url: URL
    var active: Bool
    var notify: Bool
    var entries: [Entry] = []
    var name = "Unknown feed name"
    var desc = "Unknown feed description"

    init(url: URL, active: Bool, notify: Bool) {
        self.url = url
        self.active = active
        self.notify = notify
    }
}

struct GHRelease: Decodable {
    let tag_name: String
}

enum MiniTitles: Int {
    case nowhere, left, centre, right
}

enum UnreadClearing: Int {
    case view, click
}

enum DateTimeVisibility: Int {
    case dateTime, date, time
}

enum WrapTrimPreference: Int {
    case wrapped, trimmed, unlimited
}

class AppSettings {
    /* idea:
     var showTooltips: Bool {
        get { return ud.bool(stuff) }
        set { ud.set(stuff) }
     }
     */

    let ud = UserDefaults.standard

    var doAutofetch = true
    var autofetchInterval = 60 // minutes
    var doUpdateCheck = true

    var (showFeedTitle, showFeedDesc) = (true, false)
    var (showTitles, showDescs, showDates, showAuthors) = (true, true, true, false)
    var shouldHandleHTML = true
    var showUnreadMarkers = true
    var showTooltips = true

    var unreadClearing: UnreadClearing = .view
    var dateTimeOption: DateTimeVisibility = .dateTime
    var miniTitlePosition: MiniTitles = .left
    var wrapTrimOption: WrapTrimPreference = .wrapped

    var entryLimit = 10
    var maxTextWidth = 72 // characters
    var maxTextLines = 8

    init() {
        UserDefaults.standard.register( // set default UserDefaults if they do not exist
            defaults: [
                "feed_urls": [],
                "feed_notifications": [],
                "feed_active": [],
                "max_feed_entries": entryLimit,
                "autofetch_time": autofetchInterval,
                "should_autofetch": doAutofetch,
                "should_display_feed_title": showFeedTitle,
                "should_display_feed_description": showFeedDesc,
                "should_display_title": showTitles,
                "should_display_description": showDescs,
                "should_display_date": showDates,
                "should_display_author": showAuthors,
                "should_handle_html": shouldHandleHTML,
                "should_mark_unread": showUnreadMarkers,
                "should_show_tooltips": showTooltips,
                "should_check_updates": doUpdateCheck,
                "unread_clearing_option": unreadClearing.rawValue,
                "date_time_option": dateTimeOption.rawValue,
                "wrap_trim_option": wrapTrimOption.rawValue,
                "minititles_position": miniTitlePosition.rawValue
            ]
        )

        doAutofetch = ud.bool(forKey: "should_autofetch")
        autofetchInterval = ud.integer(forKey: "autofetch_time")

        showFeedTitle = ud.bool(forKey: "should_display_feed_title")
        showFeedDesc = ud.bool(forKey: "should_display_feed_description")
        showTitles = ud.bool(forKey: "should_display_title")
        showDescs = ud.bool(forKey: "should_display_description")
        showDates = ud.bool(forKey: "should_display_date")
        showAuthors = ud.bool(forKey: "should_display_author")
        shouldHandleHTML = ud.bool(forKey: "should_handle_html")
        showUnreadMarkers = ud.bool(forKey: "should_mark_unread")
        showTooltips = ud.bool(forKey: "should_show_tooltips")
        doUpdateCheck = ud.bool(forKey: "should_check_updates")
        entryLimit = ud.integer(forKey: "max_feed_entries")

        unreadClearing = UnreadClearing(rawValue: ud.integer(forKey: "unread_clearing_option"))!
        dateTimeOption = DateTimeVisibility(rawValue: ud.integer(forKey: "date_time_option"))!
        wrapTrimOption = WrapTrimPreference(rawValue: ud.integer(forKey: "wrap_trim_option"))!
        miniTitlePosition = MiniTitles(rawValue: ud.integer(forKey: "minititles_position"))!
    }
}
