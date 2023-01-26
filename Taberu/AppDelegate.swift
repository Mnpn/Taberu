//
//  AppDelegate.swift
//  Taberu
//
//  Created by Martin Persson on 2022-06-17.
//

import Cocoa
import FeedKit
import UserNotifications

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

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    var preferencesController: NSWindowController?

    var entryID = 0
    var daijoubujanai = ""
    var fromAF = false

    var autoFetch: Bool?
    var autoFetchTime: Int?
    weak var autoFetchTimer: Timer?

    var (dFTitle, dFDesc, dTitle, dDesc, dDate, dAuthor) = (true, false, true, true, true, false)
    var handleHTML = true
    var showUnreadMarkers = true
    var deliverNotifications: [Bool] = []
    var unreadClearing = 0
    var hasUnread = false
    var showTooltips = true
    var dateTimeOption = 0
    var miniTitles = 1

    var feeds: [Feed] = []
    var maxEntries = 10
    var maxTextWidth = 72 // characters
    var maxTextLines = 8
    var wrapTrimOption = 0

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // set default UserDefaults if they do not exist
        UserDefaults.standard.register(
            defaults: [
                "feed_urls": [],
                "feed_notifications": [],
                "feed_active": [],
                "max_feed_entries": 10,
                "autofetch_time": 60, // minutes
                "should_autofetch": true,
                "should_display_feed_title": dFTitle,
                "should_display_feed_description": dFDesc,
                "should_display_title": dTitle,
                "should_display_description": dDesc,
                "should_display_date": dDate,
                "should_display_author": dAuthor,
                "should_handle_html": true,
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
        UNUserNotificationCenter.current().delegate = self
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

            for (i, ae) in finalFeed.enumerated() {
                if(handleHTML) {
                    // don't spend too much time in webkit by only using it for visible entries, and throw (much faster)
                    // regex on everything else (in case the user edits maxEntries but we don't refresh)
                    ae.description = ae.description.removeHTML(fancy: i < maxEntries)
                    ae.title = ae.title.removeHTML(fancy: i < maxEntries)
                }
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
                if activeFeeds == 1 && (dFTitle || dFDesc) {
                    let info = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                    let infoString = NSMutableAttributedString()
                    if dFTitle {
                        infoString.append(NSMutableAttributedString(string: feeds[lastActiveFeed].name))
                    }
                    if dFDesc {
                        infoString.append(NSMutableAttributedString(string: (dFTitle ? "\n" : "") + feeds[lastActiveFeed].desc))
                    }
                    info.attributedTitle = infoString
                    menu.addItem(info)
                } else if (dFTitle || dFDesc) && miniTitles == 0 { // want to display a title or desc, but there are several feeds active
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
            var unnotified: [Entry] = []
            for (i, entry) in sortedEntries.enumerated() {
                if i+1 > maxEntries { break } // only add as many (active) entries as we want
                if entry.unread { hasUnread = true }
                if entry.unread && !entry.notified && entry.parent.active && entry.parent.notify { // if not unread it will never notify
                    unnotified.append(entry)
                    entry.notified = true // this also means that viewed (but not yet read) won't sent notifications on the next autofetch
                }
                let showDate = dDate && entry.item.pubDate != nil
                let showDesc = dDesc && entry.item.description != nil && entry.item.description!.filter({ !$0.isWhitespace }) != ""

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
                    tooltip += entry.item.title != nil ? ("\n" + entry.item.title! + "\n\n") : ""
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
                var title = entry.item.title ?? ""
                switch wrapTrimOption {
                    case 0: title = textWrap(prefix: "●  ", text: title, unreadOffset: unread) // wrap
                    case 1: // trim
                        if title.count > maxTextWidth {
                            title = String(title.prefix(maxTextWidth)) + "…"
                        }
                    case 2: break; // do nothing
                    default: assertionFailure("title wraptrim received unknown value '\(wrapTrimOption)'")
                }
                if dTitle {
                    attrstring.append(NSMutableAttributedString(string: title,
                                                                attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: unread ? .heavy : .regular)]))
                }

                var bottomField = (unread && dTitle) ? "   " : ""
                if entry.item.author != nil && dAuthor {
                    bottomField += entry.item.author! + (showDate ? " at " : "")
                }
                if showDate {
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
                    bottomField += (showDate || dAuthor) ? ": " : ""
                    switch wrapTrimOption {
                        case 0: bottomField += textWrap(prefix: bottomField, text: desc, unreadOffset: unread) // wrap
                        case 1: bottomField += desc.count > maxTextWidth ? String(desc.prefix(maxTextWidth)) + "…" : desc // trim
                        case 2: bottomField += desc // do nothing
                        default: assertionFailure("description wraptrim received unknown value '\(wrapTrimOption)'")
                    }
                }

                if showDate || showDesc || dAuthor {
                    attrstring.append(NSMutableAttributedString(string: (dTitle ? "\n" : "") + bottomField, attributes:
                                    [NSAttributedString.Key.foregroundColor: NSColor.darkGray,
                                     NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12)]))
                }

                if dTitle || dAuthor || showDesc || showDate {
                    entryItem.attributedTitle = attrstring
                    // store the link in the title (attr overrides the content), this lets us fetch it on click events later
                    entryItem.title = String(entry.item.link ?? "")
                    menu.addItem(entryItem)
                } else {
                    hasInvisEntries = true
                }
            }

            if hasUnread && deliverNotifications.contains(true) && fromAF && unnotified.count > 0 {
                if unnotified.count > 1 {
                    sendNotification(title: "Taberu", sub: "", desc: "There are " + String(unnotified.count) + " new entries.", url: nil)
                } else {
                    sendNotification(title: unnotified[0].parent.name,
                                     sub: unnotified[0].item.title ?? "There is one new entry.",
                                     desc: dDesc ? (unnotified[0].item.description ?? "") : "", url: unnotified[0].item.link)
                }
                fromAF = false
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
        UserDefaults.standard.set(feeds.map({ $0.active }), forKey: "feed_active")
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

        handleHTML = ud.bool(forKey: "should_handle_html")
        showUnreadMarkers = ud.bool(forKey: "should_mark_unread")
        unreadClearing = ud.integer(forKey: "unread_clearing_option")
        showTooltips = ud.bool(forKey: "should_show_tooltips")
        dateTimeOption = ud.integer(forKey: "date_time_option")
        wrapTrimOption = ud.integer(forKey: "wrap_trim_option")
        miniTitles = ud.integer(forKey: "minititles_position")

        setURLs = (ud.array(forKey: "feed_urls") ?? []) as? [String] ?? []
        deliverNotifications = (ud.array(forKey: "feed_notifications") ?? []) as? [Bool] ?? []
        var activeFeeds = (ud.array(forKey: "feed_active") ?? []) as? [Bool] ?? []
        if setURLs.count != deliverNotifications.count { // !! certain mismatch if upgrading from 1.0
            deliverNotifications = [Bool](repeating: false, count: setURLs.count)
            ud.set(deliverNotifications, forKey: "feed_notifications") // save this change to not break preferences
        }
        if setURLs.count != activeFeeds.count { // !! certain mismatch if upgrading from 1.1
            activeFeeds = [Bool](repeating: true, count: setURLs.count)
            ud.set(activeFeeds, forKey: "feed_active")
        }
        if setURLs != lastURLs {
            feeds = []
            for (i, var url) in setURLs.enumerated() {
                url = url.filter {!$0.isWhitespace} // space in "New link" causes unwrap crash
                feeds.append(Feed(url: (URL(string: url) ?? URL(string: "whitespace"))!, active: activeFeeds[i], notify: deliverNotifications[i]))
            }
        } else {
            for (i, feed) in feeds.enumerated() {
                feed.active = activeFeeds[i]
            }
        }

        Task { await reload(syncOverride: setURLs != lastURLs) }

        autoFetchTimer?.invalidate()
        if autoFetch! {
            autoFetchTimer = Timer.scheduledTimer(withTimeInterval: Double(autoFetchTime!) * 60.0, repeats: true) { timer in
                Task { self.fromAF = true; await self.reload(syncOverride: true) }
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

    // prefix is not accounted for in wrapping calculations
    func textWrap(prefix: String, text: String, unreadOffset: Bool) -> String { // word wrap mess :(
        // Q: "Why?", A: NSAttributedStrings can have NSParagraphStyles which have wrapping settings,
        // but you cannot set a max width on an NSMenu, so they're half useless.
        let words = NSString(string: text).components(separatedBy: .whitespacesAndNewlines) // split string by space, sorry in advance of your language doesn't use them! consider using description trimming instead.
        var lines: [String] = []
        var builtLine = ""
        for word in words {
            builtLine += word + " "
            // append the words to the line. if exceeding the max width, move on to making the next line.
            if builtLine.count > ((lines.count > 0) ? maxTextWidth : maxTextWidth-prefix.count) {
                lines.append(builtLine)
                builtLine = ""
            }
        }
        if builtLine.filter({!$0.isWhitespace}) != "" { lines.append(builtLine) } // add what's left of the last line unless it's empty
        if lines.count > maxTextLines { lines = Array(lines[..<maxTextLines]); lines[maxTextLines-1] += "…" } // limit line count
        var finalLine = ""
        for (i, bigline) in lines.enumerated() { // build a single string
            finalLine += (i != 0 ? "\n" : "") + ((unreadOffset && dTitle) && i != 0 ? "   " : "") + bigline
        }
        return finalLine
    }

    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    let un = UNUserNotificationCenter.current()
    func sendNotification(title: String, sub: String, desc: String, url: String?) {
        un.requestAuthorization(options: [.alert]) { (authorised, error) in
            if authorised {
                self.un.getNotificationSettings { settings in
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.subtitle = sub
                    content.body = desc
                    let request = UNNotificationRequest(identifier: url ?? "", content: content, trigger: nil)
                    self.un.add(request) { error in
                        if error != nil { print(error?.localizedDescription as Any) }
                    }
                }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void ) { // user has clicked a notification
        // alternatively we make this receive the entry's ID and look for that and get the URL
        if response.notification.request.identifier != "" {
            openURL(url: response.notification.request.identifier) // open its URL
        }
        /*
         * I thought it could be cool if the menu opened if the entry didn't have a URL.
         * Turns out we have to wait for this function to return/finish before opening it,
         * otherwise the menu will instantly close again. running the following disgrace in a Task works:
         * usleep(100000) // some arbitrary magic number..
         * await statusItem.button?.performClick(nil)
         * but is a terrible idea.
         */
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func menuDidClose(_ menu: NSMenu) {
        if unreadClearing == 0 && hasUnread { // clearing on view
            markAllRead()
        }
        createMenu()
    }
}

extension String? {
    // https://stackoverflow.com/q/25983558
    public func removeHTML(fancy: Bool) -> String? {
        guard let string = self?.data(using: String.Encoding.utf8) else { return self } // nils are also caught here
        if(fancy) { // this actually launches a webkit process, not very efficient, but is more accurate than regex.
            let options: [NSAttributedString.DocumentReadingOptionKey : Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            let attr = try? NSAttributedString(data: string, options: options, documentAttributes: nil)
            return attr?.string
        }
        return self?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
}
