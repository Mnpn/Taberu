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
NSApplication.shared.run()
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
