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
        // create a menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake(note:)), name: NSWorkspace.didWakeNotification, object: nil)

        initFeed()
        UNUserNotificationCenter.current().delegate = self

        #if RELEASE // no point in checking for updates if we're not on a release.
        if Settings.doUpdateCheck {
            checkForUpdates()
        }
        #endif
    }

    func openURL(url: String) {
        NSWorkspace.shared.open(URL(string: (URLComponents(string: url)?.string)!)!) // URLComponents makes things percentage-encoded, otherwise we risk a crash
    }

    @objc func openPreferences() {
        preferencesWindowController?.showWindow(self)
    }

    private lazy var preferencesWindowController: NSWindowController? = { // limit to one preference pane open at a time
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
        return storyboard.instantiateInitialController() as? NSWindowController
    }()

    func getTimerRemaining(_ timer: Timer?) -> String {
        guard let timer = timer, timer.isValid else { return "??" }
        let timeRemaining = timer.fireDate.timeIntervalSinceNow.rounded()
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

    @objc func didWake(note: NSNotification) {
        guard let timer = autofetchTimer, timer.isValid else { return }
        timer.fireDate = timer.fireDate // poke the timer. WTF?
        // if the reload is in the past, it will immediately trigger a reload, which is what we want!
        // if the reload is in the future, it will correctly count down to that point as if the sleep did not happen.
    }

    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

// https://stackoverflow.com/a/46369152
struct FailableDecodable<Base : Decodable> : Decodable {
    let base: Base?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.base = try? container.decode(Base.self)
    }
}
