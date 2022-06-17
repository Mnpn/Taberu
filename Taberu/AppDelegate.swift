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
        
        let validURL = (currentURL?.absoluteURL != nil)
        if !validURL {
            menu.addItem(NSMenuItem(title: "No URL provided! Set one in Preferences.", action: nil, keyEquivalent: ""))
        }
        
    
        let reload = NSMenuItem(title: "Reload", action: #selector(reload), keyEquivalent: "R")
        menu.addItem(reload)
    
        menu.addItem(NSMenuItem.separator())
        
        if feedEntries.count == 0 {
            menu.addItem(NSMenuItem(title: "Failed to fetch from set URL.", action: nil, keyEquivalent: ""))
        }
        
        for entry in feedEntries {
            if UserDefaults.standard.bool(forKey: "should_display_title") {
                menu.addItem(NSMenuItem(title: entry.title ?? "Unknown title", action: #selector(cool), keyEquivalent: ""))
            }
            
            let dDesc = UserDefaults.standard.bool(forKey: "should_display_description")
            let dDate = UserDefaults.standard.bool(forKey: "should_display_date")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "y-MM-d"
            let date = dateFormatter.string(from: entry.pubDate!)
            let desc = (entry.description ?? "Unknown description")
            
            let bottomField = (dDate ? date : "") + ((dDate && dDesc) ? ": " : "") + (dDesc ? desc : "")
            if bottomField != "" {
                menu.addItem(NSMenuItem(title: bottomField, action: nil, keyEquivalent: ""))
            }
            
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Taberu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func cool() {}
    
    // reload() is async to not delay other actions such as closing preferences
    @objc func reload() async {
        feedEntries = [] // clear current entries
        let url = UserDefaults.standard.string(forKey: "feed_url") // get latest set URL
        currentURL = URL(string: url ?? "")!
        fetch(url: currentURL!) // fetch new data
        createMenu() // refresh the menu
    }
    
    @objc func openPreferences() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
        preferencesController = storyboard.instantiateInitialController() as? NSWindowController
        preferencesController?.showWindow(nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

