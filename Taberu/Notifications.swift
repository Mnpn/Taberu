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
            deliverNotification(title: "Taberu", sub: "", desc: "There are " + String(unnotified.count) + " new entries.", url: nil)
        } else {
            deliverNotification(title: unnotified[0].parent.name,
                                sub: unnotified[0].item.title ?? "There is one new entry.",
                                desc: Settings.showDescs ? (unnotified[0].item.description ?? "") : "",
                                url: unnotified[0].item.link)
        }
    }

    func deliverNotification(title: String, sub: String, desc: String, url: String?) {
        let un = UNUserNotificationCenter.current()
        un.requestAuthorization(options: [.alert]) { (authorised, error) in
            if authorised {
                un.getNotificationSettings { settings in
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.subtitle = sub
                    content.body = desc
                    let request = UNNotificationRequest(identifier: url ?? "", content: content, trigger: nil)
                    un.add(request) { error in
                        if error != nil { print(error?.localizedDescription as Any) }
                    }
                }
            }
        }
    }

    /* user has clicked a notification */
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void ) {
        // alternatively we make this receive the entry's ID and look for that and get the URL
        // todo: maybe clear its read status if clicked
        if !response.notification.request.identifier.isEmpty {
            openURL(url: response.notification.request.identifier) // open its URL
        }
        /*
         * I thought it could be cool if the menu opened if the entry didn't have a URL.
         * Turns out we have to wait for this function to return/finish before opening it,
         * otherwise the menu will instantly close again. running the following disgrace in a Task works:
         * usleep(100000) // some arbitrary magic number..
         * await statusItem.button?.performClick(nil)
         * but is a terrible idea.
         */
    }
}
