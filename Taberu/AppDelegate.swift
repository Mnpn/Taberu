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
    weak var autoFetchTimer: Timer?
    var hasUnread = false

    var feeds: [Feed] = []
    var deliverNotifications: [Bool] = []
    var setURLs: [String] = [], lastURLs: [String] = []

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

    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
