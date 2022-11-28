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
    @IBOutlet weak var wrapTrimOption: NSPopUpButton!
    @IBOutlet weak var dateTimeOption: NSPopUpButton!
    @IBOutlet weak var authorCheck: NSButton!
    @IBOutlet weak var maxTextField: NSTextField!
    @IBOutlet weak var sanitiserCheck: NSButton!
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
    var notify: [Bool] = []
    var active: [Bool] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        feedTitleCheck?.state = tick(df.bool(forKey: "should_display_feed_title"))
        feedDescCheck?.state = tick(df.bool(forKey: "should_display_feed_description"))
        titleCheck?.state = tick(df.bool(forKey: "should_display_title"))
        descCheck?.state = tick(df.bool(forKey: "should_display_description"))
        dateCheck?.state = tick(df.bool(forKey: "should_display_date"))
        authorCheck?.state = tick(df.bool(forKey: "should_display_author"))
        unreadCheck?.state = tick(df.bool(forKey: "should_mark_unread"))
        tooltipCheck?.state = tick(df.bool(forKey: "should_show_tooltips"))
        autoFetchCheck?.state = tick(df.bool(forKey: "should_autofetch"))

        unreadClearOption?.selectItem(at: df.integer(forKey: "unread_clearing_option"))
        dateTimeOption?.selectItem(at: df.integer(forKey: "date_time_option"))
        wrapTrimOption?.selectItem(at: df.integer(forKey: "wrap_trim_option"))
        miniTitles?.selectItem(at: df.integer(forKey: "minititles_position"))

        let autoFetchTime = Int32(df.integer(forKey: "autofetch_time"))
        let isMinute = autoFetchTime / 60 < 1
        autoFetchTextField?.intValue = isMinute ? autoFetchTime : autoFetchTime / 60
        autoFetchUnit?.selectItem(at: isMinute ? 0 : 1)

        links = df.array(forKey: "feed_urls") as! [String]
        notify = df.array(forKey: "feed_notifications") as! [Bool]
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
        active = df.array(forKey: "feed_active") as! [Bool] // has to load every time the window opens
        URLTableView.reloadData()
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
        df.set(notify, forKey: "feed_notifications")
        df.set(active, forKey: "feed_active")
        df.set(Int(maxTextField.stringValue), forKey: "max_feed_entries")
        df.set(unreadClearOption.indexOfSelectedItem, forKey: "unread_clearing_option")
        df.set(dateTimeOption.indexOfSelectedItem, forKey: "date_time_option")
        df.set(wrapTrimOption.indexOfSelectedItem, forKey: "wrap_trim_option")
        df.set(miniTitles.indexOfSelectedItem, forKey: "minititles_position")
        
        let delegate = NSApplication.shared.delegate as! AppDelegate
        delegate.initFeed()
    }

    @IBAction func addRemoveURL(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 { // +
            links.append("New link")
            notify.append(false) // default notification checkbox status is unticked
            active.append(true) // default activity is enabled, hence ticked
            URLTableView.reloadData()
            URLTableView.editColumn(0, row: links.count-1, with: nil, select: true) // newest will always be at the bottom
        } else if sender.selectedSegment == 1 { // -
            if URLTableView.selectedRow > -1 {
                links.remove(at: URLTableView.selectedRow)
                notify.remove(at: URLTableView.selectedRow)
                active.remove(at: URLTableView.selectedRow)
                URLTableView.reloadData()
                linkAddRemove.setEnabled(URLTableView.selectedRow != -1, forSegment: 1)
            }
        }
    }

    func tick(_ val: Bool) -> NSControl.StateValue {
        return val ? NSControl.StateValue.on : NSControl.StateValue.off
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
        guard links.count > row && notify.count > row && active.count > row else { return nil }
        switch tableColumn?.identifier.rawValue {
            case "links": return links[row]
            case "notifications": return notify[row]
            case "active": return active[row]
            default: assertionFailure("unknown table column identifier")
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard object != nil else {
            print("moshi moshi? there's an empty value here")
            return
        }
        guard links.count > row && notify.count > row && active.count > row else { return }
        switch tableColumn?.identifier.rawValue {
            case "links": links[row] = (object as? String)!
            case "notifications": notify[row] = object as? Int == 1
            case "active": active[row] = object as? Int == 1
            default: assertionFailure("unknown table column identifier")
        }
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
                notify.remove(at: URLTableView.selectedRow)
                URLTableView.reloadData()
            }
        }
    }
}
