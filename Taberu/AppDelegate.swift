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
    var unread: Bool = true

    init(item: RSSFeedItem) {
        self.item = item
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

    var daijoubujanai = ""

    var autoFetch: Bool?
    var autoFetchTime: Int?
    weak var autoFetchTimer: Timer?

    var dFTitle, dFDesc, dTitle, dDesc, dDate, dAuthor: Bool?
    var showUnreadMarkers = true
    var hasUnread = false

    var feeds: [Feed] = []
    var maxEntries = 10

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // set default UserDefaults if they do not exist
        UserDefaults.standard.register(
            defaults: [
                "feed_url": "",
                "max_feed_entries": 10,
                "autofetch_time": 60, // minutes
                "should_autofetch": true,
                "should_display_feed_title": true,
                "should_display_feed_description": false,
                "should_display_title": true,
                "should_display_description": true,
                "should_display_date": true,
                "should_display_author": false,
                "should_mark_unread": true
            ]
        )

        // create a menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(iconName: "tray.full.fill")
        
        initFeed()
    }

    func fetch(url: URL, forFeed: Int) {
        if url.absoluteString == "" { return } // don't fetch empty strings
        daijoubujanai = "" // clear previous fetch errors
        let parser = FeedParser(URL: url)
        let result = parser.parse()
        switch result {
        case .success(let feed):
            switch feed {
            case let .atom(feed):
                for _ in feed.entries ?? [] {}
            case let .rss(feed):
                feeds[forFeed].name = feed.title ?? "Unknown title"
                feeds[forFeed].desc = feed.description ?? "Unknown description"
                for ae in feed.items ?? [] {
                    // only add new items to the feed
                    if !feeds[forFeed].entries.contains(where: { ae == $0.item }) {
                        hasUnread = true
                        feeds[forFeed].entries.append(Entry(item: ae))
                    }
                }
            case let .json(feed):
                for _ in feed.items ?? [] {}
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
                let feedEntry = NSMenuItem(title: "Placeholder", action: #selector(toggleFeedVisibility), keyEquivalent: "")
                feedEntry.attributedTitle = NSAttributedString(string: feed.name)
                feedEntry.title = String(i)
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

        var errMsg = ""
        if feeds.count == 0 {
            errMsg += "No URLs have been added!\nPlease set some in Preferences."
        } else if activeFeeds == 0 {
            errMsg += "No feeds are currently active!\nThey'll show up here if you make them visible."
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
                        infoString.append(NSMutableAttributedString(string: dFTitle! ? "\n" : "" + feeds[lastActiveFeed].desc))
                    }
                    info.attributedTitle = infoString
                    menu.addItem(info)
                } else if dFTitle! || dFDesc! { // want to display a title or desc, but there are several feeds active
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

            var allFeedEntries: [Entry] = []
            for feed in feeds {
                if feed.active {
                    allFeedEntries.append(contentsOf: feed.entries)
                }
            }
            let sortedEntries = allFeedEntries.sorted(by: { $0.item.pubDate! > $1.item.pubDate! }) // sort by date
            for (i, entry) in sortedEntries.enumerated() {
                if i+1 > maxEntries { break } // only add as many (active) entries as we want
                menu.addItem(NSMenuItem.separator())

                let entryItem = NSMenuItem(title: "Placeholder", action: #selector(entryClick), keyEquivalent: "")
                let attrstring = NSMutableAttributedString()
                if showUnreadMarkers && entry.unread {
                    attrstring.append(NSMutableAttributedString(string: "◉ ", attributes: [NSAttributedString.Key.foregroundColor: NSColor.systemRed]))
                }
                attrstring.append(NSMutableAttributedString(string: (dTitle! ? (entry.item.title ?? "Unknown title") : "")))

                var bottomField = ""
                if dAuthor! {
                    let author = entry.item.author ?? "Unknown author"
                    bottomField += author
                }
                if dDate! {
                    bottomField += dAuthor! ? " at " : ""
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "y-MM-d"
                    bottomField += dateFormatter.string(from: entry.item.pubDate!)
                }
                if dDesc! {
                    bottomField += (dDate! || dAuthor!) ? ": " : ""
                    bottomField += entry.item.description ?? "Unknown description"
                }

                if dDate! || dDesc! || dAuthor! {
                    attrstring.append(NSMutableAttributedString(string: (dTitle! ? "\n" : "") + bottomField, attributes:
                                    [NSAttributedString.Key.foregroundColor: NSColor.darkGray,
                                     NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12)]))
                }

                if dTitle! || dAuthor! || dDesc! || dDate! {
                    entryItem.attributedTitle = attrstring
                    // store the link in the title (attr overrides the content), this lets us fetch it on click events later
                    entryItem.title = String(entry.item.link ?? "")
                    menu.addItem(entryItem)
                } else {
                    menu.addItem(NSMenuItem(title: "A feed is loaded, but you're not displaying any of it!", action: nil, keyEquivalent: ""))
                    break // don't make more than one of these please
                }
            }
        }

        if errMsg != "" {
            let err = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            err.attributedTitle = NSAttributedString(string: errMsg) // attributed overrides title and lets use use \n
            menu.addItem(err)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Taberu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func toggleFeedVisibility(_ sender: NSMenuItem) {
        let index = Int(sender.title)!
        feeds[index].active = !feeds[index].active // toggle
        createMenu()
    }

    @objc func entryClick(_ sender: NSMenuItem) {
        if sender.title == "" { return }
        openURL(url: sender.title)
    }

    func openURL(url: String) {
        NSWorkspace.shared.open(URL(string: url)!)
    }

    // reload() is async to not delay other actions such as closing preferences
    func reload(syncOverride: Bool) async {
        for (i, feed) in feeds.enumerated() {
            // don't make unnecessary network requests
            if feed.url.absoluteString != "" || syncOverride { // todo: don't reload on prefs close
                setIcon(iconName: "tray.and.arrow.down.fill")
                fetch(url: feed.url, forFeed: i)
            }
        }

        createMenu() // refresh the menu

        if feeds.count == 0 {
            setIcon(iconName: "slash.circle")
        } else if daijoubujanai != "" {
            setIcon(iconName: "xmark.circle")
        } else {
            setIcon(iconName: hasUnread ? "tray.full.fill" : "tray.fill")
        }
    }

    // because calling an async function directly from the #selector causes a general protection fault :D
    @objc func bakaReload(_ sender: NSMenuItem) {
        if sender.isAlternate { initFeed() } // coming from hard refresh
        Task { await reload(syncOverride: true) }
    }

    func initFeed() {
        maxEntries = UserDefaults.standard.integer(forKey: "max_feed_entries")
        feeds = []
        let setURLs = [URL(string: UserDefaults.standard.string(forKey: "feed_url")!)] // can't get the nil op working here at all for some reason.. todo: be an array anyways
        for url in setURLs {
            feeds.append(Feed(url: url!, active: true))
        }
        autoFetch = UserDefaults.standard.bool(forKey: "should_autofetch")
        autoFetchTime = UserDefaults.standard.integer(forKey: "autofetch_time")

        dFTitle = UserDefaults.standard.bool(forKey: "should_display_feed_title")
        dFDesc = UserDefaults.standard.bool(forKey: "should_display_feed_description")
        dTitle = UserDefaults.standard.bool(forKey: "should_display_title")
        dDesc = UserDefaults.standard.bool(forKey: "should_display_description")
        dDate = UserDefaults.standard.bool(forKey: "should_display_date")
        dAuthor = UserDefaults.standard.bool(forKey: "should_display_author")

        showUnreadMarkers = UserDefaults.standard.bool(forKey: "should_mark_unread")

        Task { await reload(syncOverride: false) }

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

    func setIcon(iconName: String) {
        if let button = statusItem.button {
            DispatchQueue.main.async { // nsstaTUSbaRbutToN SetimAGe muSt be used fRom maiN tHrEad OnLY, so let's do that
                button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Taberu")
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        for feed in feeds {
            if feed.active { // only mark as read for active (visible) feeds
                for entry in feed.entries {
                    entry.unread = false
                }
            }
        }
        if hasUnread {
            setIcon(iconName: "tray.fill")
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        hasUnread = false
        createMenu()
    }
}
