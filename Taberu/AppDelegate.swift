//
//  AppDelegate.swift
//  Taberu
//
//  Created by Martin Persson on 2022-06-17.
//

import Cocoa
import FeedKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var preferencesController: NSWindowController?
    var Settings = AppSettings()

    var entryID = 0
    var userfacingError = ""
    var autofetched = false
    var autofetchTimer: Timer?
    var hasUnread = false

    var feeds: [Feed] = []
    var deliverNotifications: [Bool] = []
    var setURLs: [String] = [], lastURLs: [String] = []

    var refreshButton = NSMenuItem()
    weak var menuUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Settings.initUserDefaults()

        // create a menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        initFeed()
        UNUserNotificationCenter.current().delegate = self
    }

    func openURL(url: String) {
        NSWorkspace.shared.open(URL(string: url)!)
    }

    @objc func openPreferences() {
        preferencesWindowController?.showWindow(self)
    }

    private lazy var preferencesWindowController: NSWindowController? = { // limit to one preference pane open at a time
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
        return storyboard.instantiateInitialController() as? NSWindowController
    }()

    func getTimerRemaining(_ timer: Timer!) -> String {
        guard timer != nil && timer.isValid else { return "??" }
        let timeRemaining = timer.fireDate.timeIntervalSinceNow
        if timeRemaining <= 0 { return "00:00" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        if timeRemaining > 3600 { // show hours if time remaining is > 1h
            formatter.allowedUnits.insert(.hour)
        }
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: timeRemaining)!
    }

    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
