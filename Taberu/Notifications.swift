//
//  Notifications.swift
//  Taberu
//
//  Created by Martin Persson on 2023-02-11.
//

import UserNotifications

extension AppDelegate: UNUserNotificationCenterDelegate {
    func sendNotifications(entries: [Entry]) {
        guard autofetched else { return }
        // only keep entries from active feeds that have not already notified
        let unnotified: [Entry] = entries.filter { $0.unread && !$0.notified && $0.parent.active && $0.parent.notify }
        guard unnotified.count > 0 else { return }
        hasUnread = true

        unnotified.forEach { $0.notified = true } // viewed (but not yet read) entries won't sent notifications on the next autofetch

        if unnotified.count > 1 {
            deliverNotification(title: "Taberu", sub: "", desc: "There are " + String(unnotified.count) + " new entries.", entryIDs: unnotified.map { $0.id })
        } else {
            deliverNotification(title: unnotified[0].parent.name,
                                sub: unnotified[0].item.title ?? "There is one new entry.",
                                desc: Settings.showDescs ? (unnotified[0].item.description ?? "") : "",
                                url: unnotified[0].item.link,
                                entryIDs: [unnotified[0].id])
        }
    }

    func deliverNotification(title: String, sub: String, desc: String, url: String? = nil, entryIDs: [Int] = []) {
        let un = UNUserNotificationCenter.current()
        un.requestAuthorization(options: [.alert]) { (authorised, error) in
            if authorised {
                un.getNotificationSettings { settings in
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.subtitle = sub
                    content.body = desc
                    if entryIDs.count == 1 {
                        content.categoryIdentifier = "new_entry_notif"
                    } else if entryIDs.count > 1 {
                        content.categoryIdentifier = "new_entries_notif"
                    }
                    content.userInfo = [ "ids" : entryIDs ]

                    let request = UNNotificationRequest(identifier: url ?? "", content: content, trigger: nil)
                    un.add(request) { error in
                        if error != nil { print(error?.localizedDescription as Any) }
                    }
                }
            }
        }
    }

    /* user has clicked a notification */
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // alternatively we make this receive the entry's ID and look for that and get the URL

        if !response.notification.request.content.userInfo.isEmpty { // there are entries to read
            for feed in feeds where feed.active {
                for entry in feed.entries {
                    if (response.notification.request.content.userInfo["ids"] as! [Int]).contains(entry.id) {
                        entry.unread = false
                    }
                }
            }
        }

        if !(response.actionIdentifier == "markread" || response.actionIdentifier == "markallread")
            && !response.notification.request.identifier.isEmpty {
            openURL(url: response.notification.request.identifier) // open its URL
        }

        createMenu()
        updateIcon()
    }
}
