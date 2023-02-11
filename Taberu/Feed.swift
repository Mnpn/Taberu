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
    // reload() is async to not delay other actions such as closing preferences
    func reload(syncOverride: Bool) async {
        updateIcon(icon: "tray.and.arrow.down.fill")
        for (i, feed) in feeds.enumerated() {
            if (feed.url.absoluteString != "" && setURLs != lastURLs) || syncOverride {
                fetch(url: feed.url, forFeed: i)
            }
        }
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

        autoFetchTimer?.invalidate()
        if Settings.doAutofetch {
            autoFetchTimer = Timer.scheduledTimer(withTimeInterval: Double(Settings.autofetchInterval) * 60.0, repeats: true) { timer in
                Task { self.autofetched = true; await self.reload(syncOverride: true); self.autofetched = false }
            }
        }
    }

    func fetch(url: URL, forFeed: Int) {
        guard !url.absoluteString.isEmpty else { return } // don't fetch empty strings
        userfacingError = "" // clear previous fetch errors
        let parser = FeedParser(URL: url)
        let result = parser.parse()
        switch result {
        case .success(let feed):
            var finalFeed: [RSSFeedItem] = [] // JSON & Atom feeds will also be stores as RSS items
            switch feed {
            case let .atom(feed):
                feeds[forFeed].name = feed.title ?? "Unknown Atom feed title"
                feeds[forFeed].desc = feed.subtitle?.value ?? "This Atom feed does not have a description"
                for ai in feed.entries ?? [] {
                    let rssFI = RSSFeedItem.init()
                    rssFI.title = ai.title
                    rssFI.description = ai.summary?.value
                    rssFI.pubDate = ai.updated ?? ai.published
                    rssFI.author = ai.authors?.first?.name
                    rssFI.link = ai.links?.first?.attributes?.href
                    finalFeed.append(rssFI)
                }
            case let .rss(feed):
                feeds[forFeed].name = feed.title ?? "Unknown RSS feed title"
                feeds[forFeed].desc = feed.description ?? "This RSS feed does not have a description"
                for ri in feed.items ?? [] {
                    ri.pubDate = ri.dublinCore?.dcDate ?? ri.pubDate
                    finalFeed.append(ri)
                }
            case let .json(feed):
                feeds[forFeed].name = feed.title ?? "Unknown JSON feed title"
                feeds[forFeed].desc = feed.description ?? "This JSON feed does not have a description"
                for ji in feed.items ?? [] {
                    let rssFI = RSSFeedItem.init()
                    rssFI.title = ji.title
                    rssFI.description = ji.contentText ?? ji.contentHtml
                    rssFI.pubDate = ji.dateModified ?? ji.datePublished
                    rssFI.author = ji.author?.name
                    rssFI.link = ji.url
                    finalFeed.append(rssFI)
                }
            }

            for (i, ae) in finalFeed.enumerated() {
                if Settings.shouldHandleHTML {
                    // don't spend too much time in webkit by only using it for visible entries, and throw (much faster)
                    // regex on everything else (in case the user edits maxEntries but we don't refresh)
                    ae.title = ae.title.removeHTML(fancy: i < Settings.entryLimit)
                    ae.description = ae.description.removeHTML(fancy: i < Settings.entryLimit)
                }
                // only add new items to the feed..
                if !feeds[forFeed].entries.contains(where: { ae == $0.item }) {
                    hasUnread = true
                    feeds[forFeed].entries.append(Entry(item: ae, parent: feeds[forFeed], id: entryID))
                    entryID += 1
                }
            }

            // ..but let's make sure to delete anything which is no longer present
            for entry in feeds[forFeed].entries {
                if !finalFeed.contains(where: { entry.item == $0 }) {
                    feeds[forFeed].entries.removeAll(where: { entry.item == $0.item })
                }
            }

        case .failure(let error):
            print(error)
            userfacingError = error.localizedDescription
        }
    }
}
