//
//  PreferencesViewController.swift
//  Taberu
//
//  Created by Martin Persson on 2022-06-17.
//

import Cocoa

class PreferencesViewController: NSViewController {
    @IBOutlet weak var URLTextField: NSTextField!
    @IBOutlet weak var autoFetchCheck: NSButton!
    @IBOutlet weak var autoFetchTextField: NSTextField!
    @IBOutlet weak var autoFetchUnit: NSPopUpButton!
    @IBOutlet weak var feedTitleCheck: NSButton!
    @IBOutlet weak var feedDescCheck: NSButton!
    @IBOutlet weak var titleCheck: NSButton!
    @IBOutlet weak var descCheck: NSButton!
    @IBOutlet weak var dateCheck: NSButton!
    @IBOutlet weak var authorCheck: NSButton!
    @IBOutlet weak var maxTextField: NSTextField!
    
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet var link: NSTextView!
    
    let df = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        feedTitleCheck?.state = df.bool(forKey: "should_display_feed_title") ? NSControl.StateValue.on : NSControl.StateValue.off
        feedDescCheck?.state = df.bool(forKey: "should_display_feed_description") ? NSControl.StateValue.on : NSControl.StateValue.off
        titleCheck?.state = df.bool(forKey: "should_display_title") ? NSControl.StateValue.on : NSControl.StateValue.off
        descCheck?.state = df.bool(forKey: "should_display_description") ? NSControl.StateValue.on : NSControl.StateValue.off
        dateCheck?.state = df.bool(forKey: "should_display_date") ? NSControl.StateValue.on : NSControl.StateValue.off
        authorCheck?.state = df.bool(forKey: "should_display_author") ? NSControl.StateValue.on : NSControl.StateValue.off
        autoFetchCheck?.state = df.bool(forKey: "should_autofetch") ? NSControl.StateValue.on : NSControl.StateValue.off

        let autoFetchTime = Int32(df.integer(forKey: "autofetch_time"))
        let isMinute = autoFetchTime / 60 < 1
        autoFetchTextField?.intValue = isMinute ? autoFetchTime : autoFetchTime / 60
        autoFetchUnit?.selectItem(at: isMinute ? 0 : 1)

        URLTextField?.stringValue = df.string(forKey: "feed_url") ?? ""
        maxTextField?.stringValue = String(df.integer(forKey: "max_feed_entries"))
        
        // https://stackoverflow.com/questions/3015796
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionLabel.stringValue = "Taberu \(version) (build \(build))"
        
        // https://stackoverflow.com/questions/7055131
        // poke the automatic link detection.. lol
        link.isEditable = true
        link.checkTextInDocument(nil)
        link.isEditable = false

        self.preferredContentSize = NSMakeSize(450, 300)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window!.styleMask.remove(.resizable)
        view.window!.center()
        NSApp.activate(ignoringOtherApps: true)
        view.window!.makeKeyAndOrderFront(nil)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        df.set(feedTitleCheck.state == NSControl.StateValue.on, forKey: "should_display_feed_title")
        df.set(feedDescCheck.state == NSControl.StateValue.on, forKey: "should_display_feed_description")
        df.set(titleCheck.state == NSControl.StateValue.on, forKey: "should_display_title")
        df.set(descCheck.state == NSControl.StateValue.on, forKey: "should_display_description")
        df.set(dateCheck.state == NSControl.StateValue.on, forKey: "should_display_date")
        df.set(authorCheck.state == NSControl.StateValue.on, forKey: "should_display_author")
        df.set(autoFetchCheck.state == NSControl.StateValue.on, forKey: "should_autofetch")
        df.set(autoFetchTextField.intValue * Int32(pow(60.0, Double(autoFetchUnit.indexOfSelectedItem))),
               forKey: "autofetch_time") // x*60^0 = minutes, x*60^1 = hours in minutes
        df.set(URLTextField.stringValue, forKey: "feed_url")
        df.set(Int(maxTextField.stringValue), forKey: "max_feed_entries")
        
        let delegate = NSApplication.shared.delegate as! AppDelegate
        delegate.initFeed()
    }
}
