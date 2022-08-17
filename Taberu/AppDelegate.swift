//
//  AppDelegate.swift
//  Taberu
//
//  Created by Martin Persson on 2022-06-17.
//

import Cocoa
import FeedKit

class Entry {
    let item: RSSFeedItem
    let parent: Feed
    let id: Int
    var unread: Bool = true

    init(item: RSSFeedItem, parent: Feed, id: Int) {
        self.item = item
        self.parent = parent
        self.id = id
    }
}

class Feed {
    let url: URL
    var active: Bool
    var entries: [Entry] = []
    var name = "Unknown feed name"
    var desc = "Unknown feed description"

    init(url: URL, active: Bool) {
        self.url = url
        self.active = active
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var preferencesController: NSWindowController?

    var entryID = 0
    var daijoubujanai = ""

    var autoFetch: Bool?
    var autoFetchTime: Int?
    weak var autoFetchTimer: Timer?

    var dFTitle, dFDesc, dTitle, dDesc, dDate, dAuthor: Bool?
    var showUnreadMarkers = true
    var unreadClearing = 0
    var hasUnread = false
    var showTooltips = true
    var dateTimeOption = 0
    var miniTitles = 1

    var feeds: [Feed] = []
    var maxEntries = 10
    var maxDescLength = 86 // characters
    var wrapTrimOption = 0

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // set default UserDefaults if they do not exist
        UserDefaults.standard.register(
            defaults: [
                "feed_urls": [],
                "max_feed_entries": 10,
                "autofetch_time": 60, // minutes
                "should_autofetch": true,
                "should_display_feed_title": true,
                "should_display_feed_description": false,
                "should_display_title": true,
                "should_display_description": true,
                "should_display_date": true,
                "should_display_author": false,
                "should_mark_unread": true,
                "should_show_tooltips": true,
                "unread_clearing_option": 0, // on view
                "date_time_option": 0, // both date & time
                "wrap_trim_option": 0, // wrap
                "minititles_position": 1 // to the left
            ]
        )

        // create a menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(icon: "tray.full.fill")
        
        initFeed()
    }

    func fetch(url: URL, forFeed: Int) {
        if url.absoluteString == "" { return } // don't fetch empty strings
        daijoubujanai = "" // clear previous fetch errors
        let parser = FeedParser(URL: url)
        let result = parser.parse()
        switch result {
        case .success(let feed):
            var finalFeed: [RSSFeedItem] = [] // JSON & Atom feeds will also be stores as RSS items
            switch feed {
            case let .atom(feed):
                feeds[forFeed].name = feed.title ?? "Unknown Atom feed title"
                feeds[forFeed].desc = feed.subtitle?.value ?? "This Atom feed does not have a description"
                for ai in feed.entries ?? [] {
                    let rssFI = RSSFeedItem.init()
                    rssFI.title = ai.title
                    rssFI.description = ai.summary?.value
                    rssFI.pubDate = ai.updated ?? ai.published
                    rssFI.author = ai.authors?.first?.name
                    rssFI.link = ai.links?.first?.attributes?.href
                    finalFeed.append(rssFI)
                }
            case let .rss(feed):
                feeds[forFeed].name = feed.title ?? "Unknown RSS feed title"
                feeds[forFeed].desc = feed.description ?? "This RSS feed does not have a description"
                for ri in feed.items ?? [] {
                    ri.pubDate = ri.dublinCore?.dcDate ?? ri.pubDate
                    finalFeed.append(ri)
                }
            case let .json(feed):
                feeds[forFeed].name = feed.title ?? "Unknown JSON feed title"
                feeds[forFeed].desc = feed.description ?? "This JSON feed does not have a description"
                for ji in feed.items ?? [] {
                    let rssFI = RSSFeedItem.init()
                    rssFI.title = ji.title
                    rssFI.description = ji.contentText ?? ji.contentHtml
                    rssFI.pubDate = ji.dateModified ?? ji.datePublished
                    rssFI.author = ji.author?.name
                    rssFI.link = ji.url
                    finalFeed.append(rssFI)
                }
            }

            for ae in finalFeed {
                // only add new items to the feed..
                if !feeds[forFeed].entries.contains(where: { ae == $0.item }) {
                    hasUnread = true
                    feeds[forFeed].entries.append(Entry(item: ae, parent: feeds[forFeed], id: entryID))
                    entryID += 1
                }
            }

            // ..but let's make sure to delete anything which is no longer present
            for entry in feeds[forFeed].entries {
                if !finalFeed.contains(where: { entry.item == $0 }) {
                    feeds[forFeed].entries.removeAll(where: { entry.item == $0.item })
                }
            }

        case .failure(let error):
            print(error)
            daijoubujanai = error.localizedDescription
        }
    }

    func createMenu() {
        let menu = NSMenu()
        menu.delegate = self

        if feeds.count > 1 {
            let feedOption = NSMenuItem(title: "Active feeds", action: nil, keyEquivalent: "")
            let feedSelector = NSMenu()

            for (i, feed) in feeds.enumerated() {
                let feedEntry = NSMenuItem(title: feed.name, action: #selector(toggleFeedVisibility), keyEquivalent: "")
                feedEntry.tag = i
                feedEntry.state = feed.active ? NSControl.StateValue.on : NSControl.StateValue.off
                feedSelector.addItem(feedEntry)
            }
            menu.setSubmenu(feedSelector, for: feedOption)
            menu.addItem(feedOption)
        }

        var activeFeeds = 0
        var lastActiveFeed = 0
        for (i, feed) in feeds.enumerated() {
            if feed.active { activeFeeds += 1; lastActiveFeed = i }
        }

        var hasInvisEntries = false
        var errMsg = ""
        if feeds.count == 0 {
            errMsg += "No URLs have been added!\nPlease set some in Preferences."
        } else if activeFeeds == 0 {
            errMsg += "No feeds are currently active!\nThey'll show up here if you make them visible."
            setIcon(icon: "tray.fill") // jank
        } else {
            if daijoubujanai != "" {
                errMsg += "Failed to fetch from one or more URLs:\n" + daijoubujanai
            } else {
                if activeFeeds == 1 && (dFTitle! || dFDesc!) {
                    let info = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                    let infoString = NSMutableAttributedString()
                    if dFTitle! {
                        infoString.append(NSMutableAttributedString(string: feeds[lastActiveFeed].name))
                    }
                    if dFDesc! {
                        infoString.append(NSMutableAttributedString(string: (dFTitle! ? "\n" : "") + feeds[lastActiveFeed].desc))
                    }
                    info.attributedTitle = infoString
                    menu.addItem(info)
                } else if (dFTitle! || dFDesc!) && miniTitles == 0 { // want to display a title or desc, but there are several feeds active
                    menu.addItem(NSMenuItem(title: "Displaying content from several feeds", action: nil, keyEquivalent: ""))
                }
            }

            let refresh = NSMenuItem(title: "Refresh", action: #selector(bakaReload), keyEquivalent: "r")
            let refreshString = NSMutableAttributedString(string: "Refresh")
            if autoFetch! {
                refreshString.append(NSMutableAttributedString(string: " (Auto-fetch is on)", attributes:
                                    [NSAttributedString.Key.foregroundColor: NSColor.darkGray]))
            }
            refresh.attributedTitle = refreshString
            menu.addItem(refresh)

            let hardRefresh = menu.addItem(withTitle: "Refresh and Reset All Entries", action: #selector(bakaReload), keyEquivalent:"r")
            hardRefresh.isAlternate = true
            hardRefresh.keyEquivalentModifierMask = [.option] //, .command]

            if unreadClearing == 1 && hasUnread && showUnreadMarkers {
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "Mark all as read", action: #selector(markAllRead), keyEquivalent: "m"))
            }

            var allFeedEntries: [Entry] = []
            for feed in feeds {
                if feed.active {
                    allFeedEntries.append(contentsOf: feed.entries)
                }
            }
            let sortedEntries = allFeedEntries.sorted(by: { $0.item.pubDate ?? Date.init() > $1.item.pubDate ?? Date.init() }) // sort by date
            hasUnread = false
            for (i, entry) in sortedEntries.enumerated() {
                if i+1 > maxEntries { break } // only add as many (active) entries as we want
                if entry.unread { hasUnread = true }
                let showDate = dDate! && entry.item.pubDate != nil
                let showDesc = dDesc! && entry.item.description != nil && entry.item.description!.filter({ !$0.isWhitespace }) != ""

                menu.addItem(NSMenuItem.separator())

                let entryItem = NSMenuItem(title: "Placeholder", action: #selector(entryClick), keyEquivalent: "")
                entryItem.tag = entry.id
                let attrstring = NSMutableAttributedString()
                if activeFeeds > 1 && entry.parent.name != "Unknown feed name" { // && (dFTitle! || dFDesc!) ?
                    if miniTitles != 0 {
                        let paragraph = NSMutableParagraphStyle()
                        switch miniTitles {
                            case 1: paragraph.alignment = .left
                            case 2: paragraph.alignment = .center
                            case 3:  paragraph.alignment = .right
                            default: assertionFailure("Hit an unknown minititle position")
                        }
                        attrstring.append(NSMutableAttributedString(string: entry.parent.name + "\n", attributes:
                            [NSAttributedString.Key.foregroundColor: NSColor.gray,
                            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 10),
                             .paragraphStyle: paragraph]))
                    }
                }
                if showTooltips {
                    var tooltip = "From \"" + entry.parent.name + "\"\n"
                    tooltip += entry.item.description != nil ? ("\nDescription:\n\"" + entry.item.description! + "\"\n") : ""
                    tooltip += entry.item.link != nil ? "\nClick to visit page." : "\""
                    entryItem.toolTip = tooltip
                }
                let unread = showUnreadMarkers && entry.unread
                if unread {
                    // baseline is NSFont.systemFont(ofSize: 13, weight: .heavy).capHeight - NSFont.systemFont(ofSize: 7).capHeight) / 2
                    attrstring.append(NSMutableAttributedString(string: "●  ", attributes:
                                                                    [NSAttributedString.Key.foregroundColor: NSColor.controlAccentColor, NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7), NSAttributedString.Key.baselineOffset: 2.113]))
                }
                attrstring.append(NSMutableAttributedString(string: (dTitle! ? (entry.item.title ?? "Unknown title") : ""),
                    attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: unread ? .heavy : .regular)]))

                var bottomField = (unread && dTitle!) ? "   " : ""
                if dAuthor! {
                    let author = entry.item.author ?? "Unknown author"
                    bottomField += author
                }
                if showDate {
                    bottomField += dAuthor! ? " at " : ""
                    let dateFormatter = DateFormatter()
                    switch dateTimeOption {
                        case 0: dateFormatter.dateFormat = "y-MM-dd HH:mm:ss"
                        case 1: dateFormatter.dateFormat = "y-MM-dd"
                        case 2: dateFormatter.dateFormat = "HH:mm:ss"
                        default: assertionFailure("Hit an unknown date & time option")
                    }
                    bottomField += dateFormatter.string(from: entry.item.pubDate!)
                }
                if showDesc {
                    let desc = entry.item.description ?? "No description"
                    bottomField += (showDate || dAuthor!) ? ": " : ""
                    if wrapTrimOption == 0 { // wrap
                        bottomField += textWrap(preExisting: bottomField, new: desc, unread: unread)
                    } else if wrapTrimOption == 1 { // trim
                        bottomField += desc.count > maxDescLength ? String(desc.prefix(maxDescLength)) + "…" : desc
                    } else { // do nothing special
                        bottomField += desc
                    }
                }

                if showDate || showDesc || dAuthor! {
                    attrstring.append(NSMutableAttributedString(string: (dTitle! ? "\n" : "") + bottomField, attributes:
                                    [NSAttributedString.Key.foregroundColor: NSColor.darkGray,
                                     NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12)]))
                }

                if dTitle! || dAuthor! || showDesc || showDate {
                    entryItem.attributedTitle = attrstring
                    // store the link in the title (attr overrides the content), this lets us fetch it on click events later
                    entryItem.title = String(entry.item.link ?? "")
                    menu.addItem(entryItem)
                } else {
                    hasInvisEntries = true
                }
            }
        }

        if hasInvisEntries {
            let nonDisplayedEntries = NSMenuItem(title: "Placeholder", action: nil, keyEquivalent: "")
            nonDisplayedEntries.attributedTitle = NSAttributedString(string: "One or more entries are hidden because they lack\ninfo to display with your currently set preferences.")
            menu.addItem(nonDisplayedEntries)
        }

        if unreadClearing == 1 && !hasUnread && showUnreadMarkers { // I just wanted "mark as read" above the list :(
            let index = menu.indexOfItem(withTitle: "Mark all as read")
            if index != -1 {
                menu.removeItem(at: index)
            }
        }

        if errMsg != "" {
            let err = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            err.attributedTitle = NSAttributedString(string: errMsg) // attributed overrides title and lets us use \n
            menu.addItem(err)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Taberu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func toggleFeedVisibility(_ sender: NSMenuItem) {
        let index = sender.tag
        feeds[index].active = !feeds[index].active // toggle
        createMenu()
        setIcon()
    }

    @objc func markAllRead() {
        for feed in feeds {
            if feed.active { // only mark as read for active (visible) feeds
                for entry in feed.entries {
                    entry.unread = false
                }
            }
        }
        hasUnread = false
        createMenu()
        setIcon()
    }

    @objc func entryClick(_ sender: NSMenuItem) {
        if unreadClearing == 1 { // clear on click
            for feed in feeds {
                if let entry = feed.entries.first(where: { $0.id == sender.tag }) {
                    entry.unread = false
                    createMenu()
                    setIcon()
                    break
                }
            }
        }
        if sender.title == "" { return }
        openURL(url: sender.title)
    }

    func openURL(url: String) {
        NSWorkspace.shared.open(URL(string: url)!)
    }

    var setURLs: [String] = [], lastURLs: [String] = []
    // reload() is async to not delay other actions such as closing preferences
    func reload(syncOverride: Bool) async {
        for (i, feed) in feeds.enumerated() {
            if (feed.url.absoluteString != "" && setURLs != lastURLs) || syncOverride {
                setIcon(icon: "tray.and.arrow.down.fill")
                fetch(url: feed.url, forFeed: i)
            }
        }
        lastURLs = setURLs

        createMenu() // refresh the menu
        setIcon()
    }

    // because calling an async function directly from the #selector causes a general protection fault :D
    @objc func bakaReload(_ sender: NSMenuItem) {
        if sender.isAlternate { lastURLs = []; initFeed() } // coming from hard refresh
        Task { await reload(syncOverride: true) }
    }

    func initFeed() {
        let ud = UserDefaults.standard
        maxEntries = ud.integer(forKey: "max_feed_entries")

        autoFetch = ud.bool(forKey: "should_autofetch")
        autoFetchTime = ud.integer(forKey: "autofetch_time")

        dFTitle = ud.bool(forKey: "should_display_feed_title")
        dFDesc = ud.bool(forKey: "should_display_feed_description")
        dTitle = ud.bool(forKey: "should_display_title")
        dDesc = ud.bool(forKey: "should_display_description")
        dDate = ud.bool(forKey: "should_display_date")
        dAuthor = ud.bool(forKey: "should_display_author")

        showUnreadMarkers = ud.bool(forKey: "should_mark_unread")
        unreadClearing = ud.integer(forKey: "unread_clearing_option")
        showTooltips = ud.bool(forKey: "should_show_tooltips")
        dateTimeOption = ud.integer(forKey: "date_time_option")
        wrapTrimOption = ud.integer(forKey: "wrap_trim_option")
        miniTitles = ud.integer(forKey: "minititles_position")

        setURLs = (ud.array(forKey: "feed_urls") ?? []) as? [String] ?? []
        if setURLs != lastURLs {
            feeds = []
            for var url in setURLs {
                url = url.filter {!$0.isWhitespace} // space in "New link" causes unwrap crash
                feeds.append(Feed(url: (URL(string: url) ?? URL(string: "whitespace"))!, active: true))
            }
        }

        Task { await reload(syncOverride: setURLs != lastURLs) }

        autoFetchTimer?.invalidate()
        if autoFetch! {
            autoFetchTimer = Timer.scheduledTimer(withTimeInterval: Double(autoFetchTime!) * 60.0, repeats: true) { timer in
                Task { await self.reload(syncOverride: true) }
            }
        }
    }

    @objc func openPreferences() {
        preferencesWindowController?.showWindow(self)
    }

    private lazy var preferencesWindowController: NSWindowController? = { // limit to one preference pane open at a time
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
        return storyboard.instantiateInitialController() as? NSWindowController
    }()

    func setIcon(icon: String? = nil) {
        var iconName = "tray.fill"
        if icon == nil {
            if feeds.count == 0 {
                iconName = "slash.circle"
            } else if daijoubujanai != "" {
                iconName = "xmark.circle"
            } else {
                iconName = hasUnread ? "tray.full.fill" : "tray.fill"
            }
        } else {
            iconName = icon!
        }
        if let button = statusItem.button {
            DispatchQueue.main.async { // nsstaTUSbaRbutToN SetimAGe muSt be used fRom maiN tHrEad OnLY, so let's do that
                button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Taberu")
            }
        }
    }

    func textWrap(preExisting: String, new: String, unread: Bool) -> String { // word wrap mess :(
        // Q: "Why?", A: NSAttributedStrings can have NSParagraphStyles which have wrapping settings,
        // but you cannot set a max width on an NSMenu, so they're half useless.
        let lines = NSString(string: new).components(separatedBy: .whitespacesAndNewlines) // split string by space, sorry in advance of your language doesn't use them! consider using description trimming instead.
        var biglines: [String] = []
        var current = ""
        for line in lines {
            current += line + " "
            if current.count > ((biglines.count > 0) ? maxDescLength : maxDescLength-preExisting.count) {
                biglines.append(current)
                current = ""
            }
        }
        if current.filter({!$0.isWhitespace}) != "" { biglines.append(current) } // add what's left unless empty
        if biglines.count > 8 { biglines = Array(biglines[..<8]); biglines[7] += "…" } // limit lines too
        var finalLine = ""
        for (i, bigline) in biglines.enumerated() {
            finalLine += (i != 0 ? "\n" : "") + ((unread && dTitle!) && i != 0 ? "   " : "") + bigline
        }
        return finalLine
    }

    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { }

    func menuDidClose(_ menu: NSMenu) {
        if unreadClearing == 0 && hasUnread { // clearing on view
            markAllRead()
        }
        createMenu()
    }
}
