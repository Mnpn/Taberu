//
//  main.swift
//  Taberu
//
//  Created by Martin Persson on 2022-11-30.
//

import Foundation
import AppKit

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.mainMenu = buildMainMenu()
NSApplication.shared.run()
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

/*
 * Taberu is an agent/UIElement, so this won't be visible to users, though is required for keyboard shortcuts to work.
 * When Main.storyboard was removed (852fd65), the default main menu went with it, breaking quite important editing shortcuts
 * such as cmd-c and cmd-v. I tried to add the MM back to the Preferences storyboard, as that's only really where it matters
 * (the user-facing app menu handles itself), but I couldn't figure it out. So, here's a (sloppy) programmatic solution.
 * This probably gives various l10n and a11y parts of macOS a bad day, so please let me know if this broke something!
 */
func buildMainMenu() -> NSMenu {
    let mainMenu = NSMenu()
    let appMenu = NSMenuItem(title: "Taberu", action: nil, keyEquivalent: "")
    let editMenu = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
    mainMenu.addItem(appMenu)
    mainMenu.addItem(editMenu)

    let appMenuContents = NSMenu()
    appMenuContents.addItem(withTitle: "Close Preferences", action: #selector(NSApplication.shared.keyWindow?.close), keyEquivalent: "w")
    appMenuContents.addItem(withTitle: "Quit Taberu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    let editMenuContents = NSMenu(title: "Edit")
    editMenuContents.addItem(withTitle: "Undo", action: #selector(EditMenuActions.undo(_:)), keyEquivalent: "z") // wtf?
    editMenuContents.addItem(withTitle: "Redo", action: #selector(EditMenuActions.redo(_:)), keyEquivalent: "Z")
    editMenuContents.addItem(NSMenuItem.separator()) // :)
    editMenuContents.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenuContents.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenuContents.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenuContents.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

    appMenu.submenu = appMenuContents
    editMenu.submenu = editMenuContents
    return mainMenu
}

// https://github.com/lapcat/Bonjeff/blob/master/source/MainMenu.swift
// how the hell does this manage to do anything at all? do we not need to call UndoManager or something, what??
@objc protocol EditMenuActions {
    func redo(_ sender: AnyObject)
    func undo(_ sender: AnyObject)
}
