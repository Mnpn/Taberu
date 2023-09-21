//
//  Updates.swift
//  Taberu
//
//  Created by Martin Persson on 2023-09-21.
//

import Foundation
import AppKit

var updateVersion: String?
let RELEASE_URL = "https://github.com/Mnpn/Taberu/releases/tag/v"
let GHAPI_RELEASES_URL = "https://api.github.com/repos/Mnpn/Taberu/releases"

func createUpdateNotice() -> NSMenuItem? {
    var updateNotice: NSMenuItem? = nil;
    if updateVersion != nil && updateVersion != Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
        updateNotice = NSMenuItem(title: "PH", action: #selector(AppDelegate.entryClick), keyEquivalent: "")
        updateNotice?.attributedTitle = NSAttributedString(string: "A new update is available (\(updateVersion!)), click to view & dismiss this notice.")
        updateNotice?.title = RELEASE_URL + updateVersion!
        updateNotice?.identifier = NSUserInterfaceItemIdentifier("menu-update-notice")
    }
    return updateNotice;
}

func checkForUpdates() {
    let task = URLSession.shared.dataTask(with: URL(string: GHAPI_RELEASES_URL)!, completionHandler: { (data, response, error) -> Void in
        if error == nil {
            let jsonResponse = data!
            do {
                let releaseData = try JSONDecoder().decode([FailableDecodable<GHRelease>].self, from: jsonResponse).compactMap { $0.base }
                updateVersion = String((releaseData.first?.tag_name.dropFirst())!) // "v1.2" -> "1.2"
            } catch { print("taberu's update check failed: " + error.localizedDescription); return }
        }
    })
    task.resume()
}
