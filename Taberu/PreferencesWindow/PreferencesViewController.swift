//
//  PreferencesViewController.swift
//  Taberu
//
//  Created by Martin Persson on 2022-06-17.
//

import Cocoa

class PreferencesViewController: NSViewController {
    @IBOutlet weak var URLTextField: NSTextField!
    @IBOutlet weak var titleCheck: NSButton!
    @IBOutlet weak var descCheck: NSButton!
    @IBOutlet weak var dateCheck: NSButton!
    
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet var link: NSTextView!
    
    let df = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleCheck?.state = df.bool(forKey: "should_display_title") ? NSControl.StateValue.on : NSControl.StateValue.off
        descCheck?.state = df.bool(forKey: "should_display_description") ? NSControl.StateValue.on : NSControl.StateValue.off
        dateCheck?.state = df.bool(forKey: "should_display_date") ? NSControl.StateValue.on : NSControl.StateValue.off
        URLTextField?.stringValue = UserDefaults.standard.string(forKey: "feed_url") ?? ""
        
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
        view.window!.makeKeyAndOrderFront(nil)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        df.set(titleCheck.state == NSControl.StateValue.on, forKey: "should_display_title")
        df.set(descCheck.state == NSControl.StateValue.on, forKey: "should_display_description")
        df.set(dateCheck.state == NSControl.StateValue.on, forKey: "should_display_date")
        df.set(URLTextField.stringValue, forKey: "feed_url")
        
        let delegate = NSApplication.shared.delegate as! AppDelegate
        Task {
            await delegate.reload()
        }
    }
}
