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
    var autoFetch: Bool?
    var autoFetchTime: Int?
    
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
                "should_display_title": true,
                "should_display_description": true,
                "should_display_date": true,
                "should_display_author": false
            ]
        )

        // create a menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(iconName: "tray.full.fill")
        
        Task { // can't call async from a sync function, so we create a task
            await reload(syncOverride: true)
        }
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
            let reload = NSMenuItem(title: "Reload" + (autoFetch! ? " (Auto-fetch is on)" : ""), action: #selector(bakaReload), keyEquivalent: "R")
            menu.addItem(reload)

            menu.addItem(NSMenuItem.separator())

            if feedEntries.count == 0 {
                menu.addItem(NSMenuItem(title: "Failed to fetch from set URL.", action: nil, keyEquivalent: ""))
            }

            let dTitle = UserDefaults.standard.bool(forKey: "should_display_title")
            let dDesc = UserDefaults.standard.bool(forKey: "should_display_description")
            let dDate = UserDefaults.standard.bool(forKey: "should_display_date")
            let dAuthor = UserDefaults.standard.bool(forKey: "should_display_author")

            var i = 0
            for entry in feedEntries {
                i += 1
                if i > maxEntries { break }
                if dTitle {
                    let titleItem = NSMenuItem(title: "Placeholder", action: #selector(entryClick), keyEquivalent: "")
                    // set the title to the index of the item in the array. the attributed title will override the
                    // user-visible NSMenuItem name, but we'll still be able to fetch the "fake index" title later!
                    titleItem.attributedTitle = NSAttributedString(string: entry.title ?? "Unknown title")
                    titleItem.title = String(feedEntries.firstIndex(of: entry) ?? -1)
                    menu.addItem(titleItem)
                }

                let descItem = NSMenuItem(title: "Placeholder", action: nil, keyEquivalent: "")

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "y-MM-d"
                let date = dateFormatter.string(from: entry.pubDate!)
                let desc = (entry.description ?? "Unknown description")
                let author = (entry.author ?? "Unknown author")

                let bottomField = (dAuthor ? author : "") + ((dAuthor && (dDate || dDesc)) ? " at " : "") + (dDate ? date : "") + ((dDate && dDesc) ? ": " : "") + (dDesc ? desc : "")
                if bottomField != "" {
                    descItem.attributedTitle = NSAttributedString(string: bottomField)
                }
                menu.addItem(descItem)
                menu.addItem(NSMenuItem.separator())
            }
        }
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
    @objc func reload(syncOverride: Bool) async {
        autoFetch = UserDefaults.standard.bool(forKey: "should_autofetch")
        autoFetchTime = UserDefaults.standard.integer(forKey: "autofetch_time")

        maxEntries = UserDefaults.standard.integer(forKey: "max_feed_entries")
        var mostRecentEntry = RSSFeedItem.init()
        if feedEntries.count > 0 {
            mostRecentEntry = feedEntries[0]
        }

        currentURL = URL(string: UserDefaults.standard.string(forKey: "feed_url")!)
        if currentURL != nil && (currentURL != lastFetchedURL || syncOverride) { // don't make unnecessary network requests
            setIcon(iconName: "tray.and.arrow.down.fill")
            feedEntries = [] // clear current entries
            fetch(url: currentURL!) // fetch new data
        }
        createMenu() // refresh the menu
        if feedEntries.count > 0 {
            setIcon(iconName: (feedEntries[0] != mostRecentEntry) ? "tray.full.fill" : "tray.fill")
        } else {
            setIcon(iconName: "bin.xmark.fill")
        }

        if autoFetch! {} else {}
    }
    
    // because calling an async function directly from the #selector causes a general protection fault :D
    @objc func bakaReload() {
        Task { await reload(syncOverride: true) }
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
    func menuWillOpen(_ menu: NSMenu) { setIcon(iconName: "tray.fill") }
}
