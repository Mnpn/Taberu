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
    
    var feedEntries: [RSSFeedItem] = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // set default UserDefaults if they do not exist
        UserDefaults.standard.register(
            defaults: [
                "feed_url": "",
                "should_display_title": true,
                "should_display_description": true,
                "should_display_date": true
            ]
        )

        // create a menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.up.arrow.down.square.fill", accessibilityDescription: "Taberu")
        }
        
        Task { // can't call async from a sync function, so we create a task
            await reload()
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
                for ae in feed.entries ?? [] {
                }
            case let .rss(feed):
                for ae in feed.items ?? [] {
                    feedEntries.append(ae)
                }
            case let .json(feed):
                for ae in feed.items ?? [] {
                }
            }
            
        case .failure(let error):
            print(error)
        }
    }
    
    func createMenu() {
        let menu = NSMenu()
        
        if currentURL?.absoluteString == nil || currentURL?.absoluteString == "" {
            menu.addItem(NSMenuItem(title: "No URL provided! Set one in Preferences.", action: nil, keyEquivalent: ""))
        } else {
            let reload = NSMenuItem(title: "Reload", action: #selector(reload), keyEquivalent: "R")
            menu.addItem(reload)

            menu.addItem(NSMenuItem.separator())

            if feedEntries.count == 0 {
                menu.addItem(NSMenuItem(title: "Failed to fetch from set URL.", action: nil, keyEquivalent: ""))
            }

            let dTitle = UserDefaults.standard.bool(forKey: "should_display_title")
            let dDesc = UserDefaults.standard.bool(forKey: "should_display_description")
            let dDate = UserDefaults.standard.bool(forKey: "should_display_date")

            for entry in feedEntries {
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

                let bottomField = (dDate ? date : "") + ((dDate && dDesc) ? ": " : "") + (dDesc ? desc : "")
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

    @IBAction func openURL(url: String) {
        if url == "" { return }
        NSWorkspace.shared.open(URL(string: url)!)
    }
    
    // reload() is async to not delay other actions such as closing preferences
    @objc func reload() async {
        feedEntries = [] // clear current entries

        currentURL = URL(string: UserDefaults.standard.string(forKey: "feed_url")!)
        if currentURL != nil {
            fetch(url: currentURL!) // fetch new data
        }
        createMenu() // refresh the menu
    }
    
    @objc func openPreferences() {
        preferencesWindowController?.showWindow(self)
    }
    
    private lazy var preferencesWindowController: NSWindowController? = { // limit to one preference pane open at a time
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
        return storyboard.instantiateInitialController() as? NSWindowController
    }()

    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

