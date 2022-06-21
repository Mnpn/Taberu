//
//  PreferencesViewController.swift
//  Taberu
//
//  Created by Martin Persson on 2022-06-17.
//

import Cocoa

class PreferencesViewController: NSViewController {
    @IBOutlet weak var autoFetchCheck: NSButton!
    @IBOutlet weak var autoFetchTextField: NSTextField!
    @IBOutlet weak var autoFetchUnit: NSPopUpButton!
    @IBOutlet weak var feedTitleCheck: NSButton!
    @IBOutlet weak var feedDescCheck: NSButton!
    @IBOutlet weak var titleCheck: NSButton!
    @IBOutlet weak var descCheck: NSButton!
    @IBOutlet weak var dateCheck: NSButton!
    @IBOutlet weak var dateTimeOption: NSPopUpButton!
    @IBOutlet weak var authorCheck: NSButton!
    @IBOutlet weak var maxTextField: NSTextField!
    @IBOutlet weak var unreadCheck: NSButton!
    @IBOutlet weak var unreadClearOption: NSPopUpButton!
    @IBOutlet weak var tooltipCheck: NSButton!
    @IBOutlet weak var miniTitles: NSPopUpButton!
    
    @IBOutlet weak var URLTableView: NSTableView!
    @IBOutlet weak var linkAddRemove: NSSegmentedControl!
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet var link: NSTextView!
    
    let df = UserDefaults.standard
    var links: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        feedTitleCheck?.state = df.bool(forKey: "should_display_feed_title") ? NSControl.StateValue.on : NSControl.StateValue.off
        feedDescCheck?.state = df.bool(forKey: "should_display_feed_description") ? NSControl.StateValue.on : NSControl.StateValue.off
        titleCheck?.state = df.bool(forKey: "should_display_title") ? NSControl.StateValue.on : NSControl.StateValue.off
        descCheck?.state = df.bool(forKey: "should_display_description") ? NSControl.StateValue.on : NSControl.StateValue.off
        dateCheck?.state = df.bool(forKey: "should_display_date") ? NSControl.StateValue.on : NSControl.StateValue.off
        authorCheck?.state = df.bool(forKey: "should_display_author") ? NSControl.StateValue.on : NSControl.StateValue.off
        unreadCheck?.state = df.bool(forKey: "should_mark_unread") ? NSControl.StateValue.on : NSControl.StateValue.off
        tooltipCheck?.state = df.bool(forKey: "should_show_tooltips") ? NSControl.StateValue.on : NSControl.StateValue.off
        autoFetchCheck?.state = df.bool(forKey: "should_autofetch") ? NSControl.StateValue.on : NSControl.StateValue.off

        unreadClearOption?.selectItem(at: df.integer(forKey: "unread_clearing_option"))
        dateTimeOption?.selectItem(at: df.integer(forKey: "date_time_option"))
        miniTitles?.selectItem(at: df.integer(forKey: "minititles_position"))

        let autoFetchTime = Int32(df.integer(forKey: "autofetch_time"))
        let isMinute = autoFetchTime / 60 < 1
        autoFetchTextField?.intValue = isMinute ? autoFetchTime : autoFetchTime / 60
        autoFetchUnit?.selectItem(at: isMinute ? 0 : 1)

        links = df.array(forKey: "feed_urls") as! [String]
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

        autoFetchTextField.formatter = nombas()
        maxTextField.formatter = nombas()

        URLTableView.dataSource = self
        URLTableView.delegate = self
        linkAddRemove.setEnabled(URLTableView.selectedRow != -1, forSegment: 1)

        self.preferredContentSize = NSMakeSize(550, 500)
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
        df.set(feedTitleCheck.state, forKey: "should_display_feed_title")
        df.set(feedDescCheck.state, forKey: "should_display_feed_description")
        df.set(titleCheck.state, forKey: "should_display_title")
        df.set(descCheck.state, forKey: "should_display_description")
        df.set(dateCheck.state, forKey: "should_display_date")
        df.set(authorCheck.state, forKey: "should_display_author")
        df.set(unreadCheck.state, forKey: "should_mark_unread")
        df.set(autoFetchCheck.state, forKey: "should_autofetch")
        df.set(autoFetchTextField.intValue * Int32(pow(60.0, Double(autoFetchUnit.indexOfSelectedItem))),
               forKey: "autofetch_time") // x*60^0 = minutes, x*60^1 = hours in minutes
        df.set(links, forKey: "feed_urls")
        df.set(Int(maxTextField.stringValue), forKey: "max_feed_entries")
        df.set(unreadClearOption.indexOfSelectedItem, forKey: "unread_clearing_option")
        df.set(dateTimeOption.indexOfSelectedItem, forKey: "date_time_option")
        df.set(miniTitles.indexOfSelectedItem, forKey: "minititles_position")
        
        let delegate = NSApplication.shared.delegate as! AppDelegate
        delegate.initFeed()
    }

    @IBAction func addRemoveURL(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 { // +
            links.append("New link")
            URLTableView.reloadData()
            URLTableView.editColumn(0, row: links.count-1, with: nil, select: true) // newest will always be at the bottom
        } else if sender.selectedSegment == 1 { // -
            if URLTableView.selectedRow > -1 {
                links.remove(at: URLTableView.selectedRow)
                URLTableView.reloadData()
                linkAddRemove.setEnabled(URLTableView.selectedRow != -1, forSegment: 1)
            }
        }
    }
}

class nombas: NumberFormatter {
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool { // wtf
        return partialString == partialString.components(separatedBy: NSCharacterSet(charactersIn: "0123456789").inverted).joined(separator: "")
    }
}

// Thanks IINA - https://github.com/iina/iina
extension PreferencesViewController: NSTableViewDelegate, NSTableViewDataSource, NSControlTextEditingDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return links.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard links.count > row else { return nil }
        return links[row]
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard let value = object as? String else { return }
        guard !value.isEmpty else {
            print("moshi moshi? there's an empty value here")
            return
        }
        guard links.count > row else { return }
        links[row] = value
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if URLTableView.selectedRowIndexes.count == 0 {
            URLTableView.reloadData()
        }
        linkAddRemove.setEnabled(URLTableView.selectedRow != -1, forSegment: 1)
    }

    // backspace key removing, segmented controls do not have keyEquivalents
    // this does not run while editing, to our advantage
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == String(Character(UnicodeScalar(NSDeleteCharacter)!)) {
            if URLTableView.selectedRow > -1 {
                links.remove(at: URLTableView.selectedRow)
                URLTableView.reloadData()
            }
        }
    }
}
