//
//  AppDelegate.swift
//  Taberu
//
//  Created by Martin Persson on 2022-06-17.
//

import Cocoa
import FeedKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    
    var preferencesController: NSWindowController?
    var currentURL: URL?
    var lastFetchedURL: URL?
    var mostRecentlyViewedEntry = RSSFeedItem.init()
    var autoFetch: Bool?
    var autoFetchTime: Int?
    weak var autoFetchTimer: Timer?

    var dFTitle: Bool?
    var dFDesc: Bool?
    var dTitle: Bool?
    var dDesc: Bool?
    var dDate: Bool?
    var dAuthor: Bool?
    
    var feedName: String?
    var feedDesc: String?
    var feedEntries: [RSSFeedItem] = []
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
                "should_display_author": false
            ]
        )

        // create a menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(iconName: "tray.full.fill")
        
        initFeed()
    }
    
    func fetch(url: URL) {
        if url.absoluteString == "" { return } // don't fetch empty strings
        let parser = FeedParser(URL: url)
        let result = parser.parse()
        switch result {
        case .success(let feed):
            switch feed {
            case let .atom(feed):
                for _ in feed.entries ?? [] {
                }
            case let .rss(feed):
                feedName = feed.title
                feedDesc = feed.description
                for ae in feed.items ?? [] {
                    feedEntries.append(ae)
                }
            case let .json(feed):
                for _ in feed.items ?? [] {
                }
            }
            
        case .failure(let error):
            print(error)
        }

        lastFetchedURL = url
    }
    
    func createMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        if currentURL?.absoluteString == nil || currentURL?.absoluteString == "" {
            menu.addItem(NSMenuItem(title: "No URL provided! Set one in Preferences.", action: nil, keyEquivalent: ""))
        } else {
            if feedEntries.count == 0 {
                menu.addItem(NSMenuItem(title: "Failed to fetch from set URL.", action: nil, keyEquivalent: ""))
            } else {
                if dFTitle! {
                    menu.addItem(NSMenuItem(title: feedName ?? "Unknown feed name", action: nil, keyEquivalent: ""))
                }
                if dFDesc! {
                    menu.addItem(NSMenuItem(title: feedDesc ?? "Unknown feed description", action: nil, keyEquivalent: ""))
                }
            }

            let refresh = NSMenuItem(title: "Refresh", action: #selector(bakaReload), keyEquivalent: "R")
            let refreshString = NSMutableAttributedString(string: "Refresh")
            if autoFetch! {
                refreshString.append(NSMutableAttributedString(string: " (Auto-fetch is on)", attributes: [NSAttributedString.Key.foregroundColor: NSColor.darkGray]))
            }
            refresh.attributedTitle = refreshString
            menu.addItem(refresh)

            var i = 0
            for entry in feedEntries {
                i += 1
                if i > maxEntries { break }

                menu.addItem(NSMenuItem.separator())
                let entryItem = NSMenuItem(title: String(feedEntries.firstIndex(of: entry) ?? -1), action: #selector(entryClick), keyEquivalent: "")
                let attrstring = NSMutableAttributedString(string: dTitle! ? (entry.title ?? "Unknown title") : "")

                var bottomField = ""
                if dAuthor! {
                    let author = entry.author ?? "Unknown author"
                    bottomField += author
                }
                if dDate! {
                    bottomField += dAuthor! ? " at " : ""
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "y-MM-d"
                    bottomField += dateFormatter.string(from: entry.pubDate!)
                }
                if dDesc! {
                    bottomField += (dDate! || dAuthor!) ? ": " : ""
                    bottomField += entry.description ?? "Unknown description"
                }

                if dDate! || dDesc! || dAuthor! {
                    attrstring.append(NSMutableAttributedString(string: (dTitle! ? "\n" : "") + bottomField, attributes:
                                    [NSAttributedString.Key.foregroundColor: NSColor.darkGray,
                                     NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12)]))
                }

                if dTitle! || dAuthor! || dDesc! || dDate! {
                    entryItem.attributedTitle = attrstring
                    // set the title to the index of the item in the array. the attributed title will override the
                    // user-visible NSMenuItem name, but we'll still be able to fetch the "fake index" title later!
                    menu.addItem(entryItem)
                } else {
                    menu.addItem(NSMenuItem(title: "A feed is loaded, but you're not displaying any of it!", action: nil, keyEquivalent: ""))
                    break // don't make more than one of these please
                }
            }
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Taberu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func entryClick(_ sender: NSMenuItem) {
        let sendingEntry = Int(sender.title)!
        if sendingEntry == -1 { return }
        openURL(url: feedEntries[sendingEntry].link ?? "")
    }

    func openURL(url: String) {
        if url == "" { return }
        NSWorkspace.shared.open(URL(string: url)!)
    }
    
    // reload() is async to not delay other actions such as closing preferences
    func reload(syncOverride: Bool) async {
        if currentURL != nil && (currentURL != lastFetchedURL || syncOverride) { // don't make unnecessary network requests
            setIcon(iconName: "tray.and.arrow.down.fill")
            feedEntries = [] // clear current entries
            fetch(url: currentURL!) // fetch new data
        }
        createMenu() // refresh the menu
        if currentURL?.absoluteString == nil || currentURL?.absoluteString == "" {
            setIcon(iconName: "slash.circle")
        } else if feedEntries.count > 0 {
            setIcon(iconName: (feedEntries[0] != mostRecentlyViewedEntry) ? "tray.full.fill" : "tray.fill")
        } else {
            setIcon(iconName: "xmark.circle") // bin.xmark.fill
        }
    }
    
    // because calling an async function directly from the #selector causes a general protection fault :D
    @objc func bakaReload() {
        Task { await reload(syncOverride: true) }
    }

    func initFeed() {
        maxEntries = UserDefaults.standard.integer(forKey: "max_feed_entries")
        currentURL = URL(string: UserDefaults.standard.string(forKey: "feed_url")!)
        autoFetch = UserDefaults.standard.bool(forKey: "should_autofetch")
        autoFetchTime = UserDefaults.standard.integer(forKey: "autofetch_time")

        dFTitle = UserDefaults.standard.bool(forKey: "should_display_feed_title")
        dFDesc = UserDefaults.standard.bool(forKey: "should_display_feed_description")
        dTitle = UserDefaults.standard.bool(forKey: "should_display_title")
        dDesc = UserDefaults.standard.bool(forKey: "should_display_description")
        dDate = UserDefaults.standard.bool(forKey: "should_display_date")
        dAuthor = UserDefaults.standard.bool(forKey: "should_display_author")

        Task { await reload(syncOverride: false) }

        autoFetchTimer?.invalidate()
        if autoFetch! {
            autoFetchTimer = Timer.scheduledTimer(withTimeInterval: Double(autoFetchTime!) * 60.0, repeats: true) { timer in
                self.bakaReload()
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
        if feedEntries.count > 0 && (currentURL?.absoluteString != nil && currentURL?.absoluteString != "") {
            setIcon(iconName: "tray.fill")
        }

        if feedEntries.count > 0 {
            mostRecentlyViewedEntry = feedEntries[0]
        }
    }
}
