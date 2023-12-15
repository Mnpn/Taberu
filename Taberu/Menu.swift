//
//  Menu.swift
//  Taberu
//
//  Created by Martin Persson on 2023-01-26.
//

import AppKit
import UserNotifications

extension AppDelegate: NSMenuDelegate {
    func createMenu() {
        let menu = NSMenu()
        menu.delegate = self

        if let updateNotice = createUpdateNotice() {
            menu.addItem(updateNotice)
            menu.addItem(NSMenuItem.separator())
        }

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

        hasUnread = false
        var hasInvisEntries = false
        var errMsg = ""
        if feeds.count == 0 {
            errMsg += "No URLs have been added!\nPlease set some in Preferences."
        } else if activeFeeds == 0 {
            errMsg += "No feeds are currently active!\nThey'll show up here if you make them visible."
        } else {
            if !userfacingError.isEmpty {
                errMsg += "Failed to fetch from one or more URLs:\n" + userfacingError
            } else {
                if activeFeeds == 1 && (Settings.showFeedTitle || Settings.showFeedDesc) {
                    let info = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                    let infoString = NSMutableAttributedString()
                    if Settings.showFeedTitle {
                        infoString.append(NSMutableAttributedString(string: feeds[lastActiveFeed].name))
                    }
                    if Settings.showFeedDesc {
                        infoString.append(NSMutableAttributedString(string: (Settings.showFeedTitle ? "\n" : "") + feeds[lastActiveFeed].desc))
                    }
                    info.attributedTitle = infoString
                    menu.addItem(info)
                } else if (Settings.showFeedTitle || Settings.showFeedDesc) && Settings.miniTitlePosition == .nowhere {
                    // want to display a title or desc, but there are several feeds active
                    menu.addItem(NSMenuItem(title: "Displaying content from several feeds", action: nil, keyEquivalent: ""))
                }
            }

            refreshButton = NSMenuItem(title: "Refresh", action: #selector(bakaReload), keyEquivalent: "r")
            menu.addItem(refreshButton)

            let hardRefresh = menu.addItem(withTitle: "Refresh and Reset All Entries", action: #selector(bakaReload), keyEquivalent:"r")
            hardRefresh.isAlternate = true
            hardRefresh.keyEquivalentModifierMask = [.option] //, .command]

            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Mark All as Read", action: #selector(markAllRead), keyEquivalent: "m"))

            var allFeedEntries: [Entry] = []
            for feed in feeds {
                if feed.active {
                    allFeedEntries.append(contentsOf: feed.entries)
                }
            }
            var sortedEntries = allFeedEntries.sorted(by: { $0.item.pubDate ?? Date.init() > $1.item.pubDate ?? Date.init() }) // sort by date
            sortedEntries = Array(sortedEntries.prefix(Settings.entryLimit)) // only add as many (active) entries as we want

            for entry in sortedEntries {
                if entry.unread { hasUnread = true }
                let showDate = Settings.showDates && entry.item.pubDate != nil
                let showDesc = Settings.showDescs && entry.item.description != nil && !entry.item.description!.filter({ !$0.isWhitespace }).isEmpty

                menu.addItem(NSMenuItem.separator())

                let entryItem = NSMenuItem(title: "Placeholder", action: #selector(entryClick), keyEquivalent: "")
                entryItem.tag = entry.id
                let attrstring = NSMutableAttributedString()
                if activeFeeds > 1 && entry.parent.name != "Unknown feed name" { // todo: check if this string comparison is needed
                    if Settings.miniTitlePosition != .nowhere {
                        let paragraph = NSMutableParagraphStyle()
                        switch Settings.miniTitlePosition {
                            case .left:   paragraph.alignment = .left
                            case .centre: paragraph.alignment = .center
                            case .right:  paragraph.alignment = .right
                            default: assertionFailure("Hit an unreasonable minititle position")
                        }
                        attrstring.append(NSMutableAttributedString(string: entry.parent.name + "\n", attributes:
                                                                        [.foregroundColor: NSColor.gray,
                                                                         .font: NSFont.systemFont(ofSize: 10),
                                                                         .paragraphStyle: paragraph]))
                    }
                }
                if Settings.showTooltips {
                    var tooltip = "From \"" + entry.parent.name + "\"\n"
                    tooltip += entry.item.title != nil ? ("\n" + entry.item.title! + "\n\n") : ""
                    tooltip += entry.item.description != nil ? ("\nDescription:\n\"" + entry.item.description! + "\"\n") : ""
                    tooltip += entry.item.link != nil ? "\nClick to visit page." : "\""
                    entryItem.toolTip = tooltip
                }

                let unread = Settings.showUnreadMarkers && entry.unread
                if unread {
                    // baseline is NSFont.systemFont(ofSize: 13, weight: .heavy).capHeight - NSFont.systemFont(ofSize: 7).capHeight) / 2
                    attrstring.append(NSMutableAttributedString(string: "●  ", attributes:
                                                                    [.foregroundColor: NSColor.controlAccentColor,
                                                                     .font: NSFont.systemFont(ofSize: 7),
                                                                     .baselineOffset: 2.113]))
                }

                if Settings.showTitles {
                    var title = entry.item.title ?? ""
                    switch Settings.wrapTrimOption {
                    case .wrapped: title = textWrap(prefix: "●  ", text: title, unreadOffset: unread)
                    case .trimmed:
                        if title.count > Settings.maxTextWidth {
                            title = title.prefix(Settings.maxTextWidth) + "…"
                        }
                    case .unlimited: break
                    }
                    attrstring.append(NSMutableAttributedString(string: title,
                                                                attributes: [.font: NSFont.systemFont(ofSize: 13, weight: unread ? .heavy : .regular)]))
                }

                var bottomField = (unread && Settings.showTitles) ? "   " : ""
                if entry.item.author != nil && Settings.showAuthors {
                    bottomField += entry.item.author! + (showDate ? " at " : "")
                }
                if showDate {
                    let dateFormatter = DateFormatter()
                    switch Settings.dateTimeOption {
                    case .dateTime: dateFormatter.dateFormat = "y-MM-dd HH:mm:ss"
                    case .date: dateFormatter.dateFormat = "y-MM-dd"
                    case .time: dateFormatter.dateFormat = "HH:mm:ss"
                    }
                    bottomField += dateFormatter.string(from: entry.item.pubDate!)
                }
                if showDesc {
                    let desc = entry.item.description!
                    bottomField += (showDate || Settings.showAuthors) ? ": " : ""
                    switch Settings.wrapTrimOption {
                    case .wrapped: bottomField += textWrap(prefix: bottomField, text: desc, unreadOffset: unread)
                    case .trimmed: bottomField += desc.count > Settings.maxTextWidth ? desc.prefix(Settings.maxTextWidth) + "…" : desc
                    case .unlimited: bottomField += desc // do nothing
                    }
                }

                if showDate || showDesc || Settings.showAuthors {
                    attrstring.append(NSMutableAttributedString(string: (Settings.showTitles ? "\n" : "") + bottomField,
                                                                attributes: [.foregroundColor: NSColor.darkGray,
                                                                             .font: NSFont.systemFont(ofSize: 12)]))
                }

                if Settings.showTitles || showDesc || showDate || Settings.showAuthors {
                    entryItem.attributedTitle = attrstring
                    entryItem.setAccessibilityLabel(attrstring.string.replacingOccurrences(of: "●", with: ". Unread entry.")) // otherwise e.g. VoiceOver reads the title (which in this case is the entry URL)

                    // store the link in the title (attr overrides the content), this lets us fetch it on click events later
                    entryItem.title = String(entry.item.link ?? "")
                    menu.addItem(entryItem)
                } else {
                    hasInvisEntries = true
                }
            }

            sendNotifications(entries: sortedEntries)
        }

        if hasInvisEntries {
            let nonDisplayedEntries = NSMenuItem(title: "Placeholder", action: nil, keyEquivalent: "")
            nonDisplayedEntries.attributedTitle = NSAttributedString(string: "One or more entries are hidden because they lack\ninfo to display with your currently set preferences.")
            menu.addItem(nonDisplayedEntries)
        }

        if let markAllAsRead = menu.item(withTitle: "Mark All as Read") {
            let shouldShowMarkAllAsRead = Settings.showUnreadMarkers && Settings.unreadClearing == .click && hasUnread
            markAllAsRead.isHidden = !shouldShowMarkAllAsRead
            menu.item(at: menu.index(of: markAllAsRead) - 1)?.isHidden = !shouldShowMarkAllAsRead
        }

        if !errMsg.isEmpty {
            let err = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            err.attributedTitle = NSAttributedString(string: errMsg) // attributed overrides title and lets us use \n
            menu.addItem(err)
        }

        appendMenuBottom(menu: menu)
        statusItem.menu = menu
    }

    func appendMenuBottom(menu: NSMenu) {
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Taberu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc func toggleFeedVisibility(_ sender: NSMenuItem) {
        let index = sender.tag
        feeds[index].active = !feeds[index].active // toggle
        UserDefaults.standard.set(feeds.map({ $0.active }), forKey: "feed_active")
        createMenu()
        updateIcon()
    }

    @objc func markAllRead() {
        for feed in feeds where feed.active { // only mark as read for active (visible) feeds
            feed.entries.forEach { $0.unread = false }
        }
        hasUnread = false
        createMenu()
        updateIcon()
    }

    @objc func entryClick(_ sender: NSMenuItem) {
        if sender.identifier == NSUserInterfaceItemIdentifier("menu-update-notice") {
            updateVersion = nil
            createMenu()
        } else {
            if Settings.unreadClearing == .click {
                for feed in feeds {
                    if let entry = feed.entries.first(where: { $0.id == sender.tag }) {
                        entry.unread = false
                        createMenu()
                        updateIcon()
                        break
                    }
                }
            }
        }
        guard !sender.title.isEmpty else { return }
        openURL(url: sender.title)
    }

    func updateIcon(icon manualIconOverride: String? = nil) {
        var iconName = manualIconOverride ?? "tray.fill"
        if manualIconOverride == nil {
            if feeds.count == 0 {
                iconName = "slash.circle"
            } else if !userfacingError.isEmpty {
                iconName = "xmark.circle"
            } else if hasUnread {
                iconName = "tray.full.fill"
            }
        }
        if let button = statusItem.button {
            DispatchQueue.main.async {
                button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Taberu")
            }
        }
    }

    func updateMenu() {
        let refreshString = NSMutableAttributedString(string: "Refresh")
        if Settings.doAutofetch {
            let remainingTime = getTimerRemaining(autofetchTimer)
            if remainingTime == "00:00" { statusItem.menu?.cancelTracking() } // close the menu if it's time to refresh.. not that nice
            refreshString.append(NSMutableAttributedString(string: " (Auto-fetch in \(remainingTime))",
                                                           attributes: [.foregroundColor: NSColor.darkGray,
                                                                        .font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)]))
        }
        refreshButton.attributedTitle = refreshString
    }

    func menuWillOpen(_ menu: NSMenu) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        if Settings.doAutofetch {
            menuUpdateTimer?.invalidate()
            menuUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.updateMenu()
            }
            RunLoop.current.add(menuUpdateTimer!, forMode: .common) // required to have the menu update while open
            menuUpdateTimer?.fire()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        if Settings.unreadClearing == .view && hasUnread { // clearing on view
            markAllRead()
        }
        if Settings.doAutofetch {
            menuUpdateTimer?.invalidate()
        }
        createMenu()
    }
}
