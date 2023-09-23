//
//  Feed.swift
//  Taberu
//
//  Created by Martin Persson on 2023-01-26.
//

import AppKit
import FeedKit
import Foundation

extension AppDelegate {
    func updateMenuItemTitle(item: NSMenuItem, newTitle: String) { // WTF?
        // the app occasionally died when the title was updated while the menu was open
        // running on the main thread helped with this. that's fair enough.
        // but obviously (/s) this needs to be a function because otherwise it goes
        // "Capture of 'refreshNotice' with non-sendable type 'NSMenuItem' in a `@Sendable` closure"
        DispatchQueue.main.async {
            item.title = newTitle
        }
    }

    // reload() is async to not delay other actions such as closing preferences
    func reload(syncOverride: Bool) async {
        updateIcon(icon: "tray.and.arrow.down.fill")

        let menu = NSMenu()
        let refreshNotice = NSMenuItem(title: "Refreshing, please wait.. (0/\(feeds.count))", action: nil, keyEquivalent: "")
        menu.addItem(refreshNotice)
        appendMenuBottom(menu: menu)
        statusItem.menu = menu

        for (i, feed) in feeds.enumerated() {
            if (feed.url.absoluteString != "" && setURLs != lastURLs) || syncOverride {
                let newTitle = "Refreshing, please wait.. (\(i + 1)/\(feeds.count))"
                updateMenuItemTitle(item: refreshNotice, newTitle: newTitle)
                feeds[i] = fetch(url: feed.url, currentData: feeds[i]) ?? feeds[i]
            }
        }
        statusItem.menu?.cancelTracking() // this closes the menu. not ideal, but changing an entire menu while it is active rarely leads to happy results.

        lastURLs = setURLs
        createMenu() // refresh the menu
        updateIcon()
    }

    // because calling an async function directly from the #selector causes a general protection fault :D
    @objc func bakaReload(_ sender: NSMenuItem) {
        guard !sender.isAlternate else { lastURLs = []; initFeed(); return } // coming from hard refresh
        Task { await reload(syncOverride: true) }
    }

    func initFeed() {
        let ud = UserDefaults.standard
        Settings = AppSettings() // re-init settings
        setURLs = (ud.array(forKey: "feed_urls") ?? []) as! [String]
        deliverNotifications = (ud.array(forKey: "feed_notifications") ?? []) as! [Bool]
        var activeFeeds = (ud.array(forKey: "feed_active") ?? []) as! [Bool]
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

        autofetchTimer?.invalidate()
        if Settings.doAutofetch {
            autofetchTimer = Timer.scheduledTimer(withTimeInterval: Double(Settings.autofetchInterval) * 60.0, repeats: true) { timer in
                Task { self.autofetched = true; await self.reload(syncOverride: true); self.autofetched = false }
            }
            RunLoop.current.add(autofetchTimer!, forMode: .common) // needed to refresh while menu is open
        }
    }

    func fetch(url: URL, currentData: Feed) -> Feed? {
        userfacingError = "" // clear previous fetch errors
        let parser = FeedParser(URL: url)
        let result = parser.parse()
        switch result {
        case .success(let feed):
            var finalFeedItems: [RSSFeedItem] = [] // JSON & Atom feeds will also be stored as RSS items
            switch feed {
            case let .atom(feed):
                currentData.name = feed.title ?? "Unknown Atom feed title"
                currentData.desc = feed.subtitle?.value ?? "This Atom feed does not have a description"
                for ai in feed.entries ?? [] {
                    let rssFI = RSSFeedItem.init()
                    rssFI.title = ai.title
                    rssFI.description = ai.summary?.value
                    rssFI.pubDate = ai.updated ?? ai.published
                    rssFI.author = ai.authors?.first?.name
                    rssFI.link = ai.links?.first?.attributes?.href
                    finalFeedItems.append(rssFI)
                }
            case let .rss(feed):
                currentData.name = feed.title ?? "Unknown RSS feed title"
                currentData.desc = feed.description ?? "This RSS feed does not have a description"
                for ri in feed.items ?? [] {
                    ri.pubDate = ri.dublinCore?.dcDate ?? ri.pubDate
                    finalFeedItems.append(ri)
                }
            case let .json(feed):
                currentData.name = feed.title ?? "Unknown JSON feed title"
                currentData.desc = feed.description ?? "This JSON feed does not have a description"
                for ji in feed.items ?? [] {
                    let rssFI = RSSFeedItem.init()
                    rssFI.title = ji.title
                    rssFI.description = ji.contentText ?? ji.contentHtml
                    rssFI.pubDate = ji.dateModified ?? ji.datePublished
                    rssFI.author = ji.author?.name
                    rssFI.link = ji.url
                    finalFeedItems.append(rssFI)
                }
            }

            for (i, ae) in finalFeedItems.enumerated() {
                if Settings.shouldHandleHTML {
                    // don't spend too much time in webkit by only using it for visible entries, and throw (much faster)
                    // regex on everything else (in case the user edits maxEntries but we don't refresh)
                    ae.title = ae.title.removeHTML(fancy: i < Settings.entryLimit)
                    ae.description = ae.description.removeHTML(fancy: i < Settings.entryLimit)
                }
                // only add new items to the feed..
                if !currentData.entries.contains(where: { ae == $0.item }) {
                    hasUnread = true
                    currentData.entries.append(Entry(item: ae, parent: currentData, id: entryID))
                    entryID += 1
                }
            }

            // ..but let's make sure to delete anything which is no longer present
            for entry in currentData.entries {
                if !finalFeedItems.contains(where: { entry.item == $0 }) {
                    currentData.entries.removeAll(where: { entry.item == $0.item })
                }
            }
            return currentData

        case .failure(let error):
            print(error)
            userfacingError = error.localizedDescription
        }
        return nil
    }
}
