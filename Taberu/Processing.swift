//
//  Processing.swift
//  Taberu
//
//  Created by Martin Persson on 2023-01-26.
//

import Foundation

extension AppDelegate {
    // prefix is not accounted for in wrapping calculations
    func textWrap(prefix: String, text: String, unreadOffset: Bool) -> String { // word wrap mess :(
        // Q: "Why?", A: NSAttributedStrings can have NSParagraphStyles which have wrapping settings,
        // but you cannot set a max width on an NSMenu, so they're half useless.
        let maxTextLines = Settings.maxTextLines, maxTextWidth = Settings.maxTextWidth
        let words = NSString(string: text).components(separatedBy: .whitespacesAndNewlines) // split string by space, sorry in advance of your language doesn't use them! consider using description trimming instead.
        var lines: [String] = []
        var builtLine = ""
        for word in words {
            builtLine += word + " "
            // append the words to the line. if exceeding the max width, move on to making the next line.
            if builtLine.count > ((lines.count > 0) ? maxTextWidth : maxTextWidth-prefix.count) {
                lines.append(builtLine)
                builtLine = ""
            }
        }
        if builtLine.filter({!$0.isWhitespace}) != "" { lines.append(builtLine) } // add what's left of the last line unless it's empty
        if lines.count > maxTextLines { lines = Array(lines[..<maxTextLines]); lines[maxTextLines-1] += "…" } // limit line count
        var finalLine = ""
        for (i, bigline) in lines.enumerated() { // build a single string
            finalLine += (i != 0 ? "\n" : "") + ((unreadOffset && Settings.showTitles) && i != 0 ? "   " : "") + bigline
        }
        return finalLine
    }
}

extension String? {
    // https://stackoverflow.com/q/25983558
    public func removeHTML(fancy: Bool) -> String? {
        guard let string = self?.data(using: String.Encoding.utf8) else { return self } // nils are also caught here
        if(fancy) { // this actually launches a webkit process, not very efficient, but is more accurate than regex.
            let options: [NSAttributedString.DocumentReadingOptionKey : Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            let attr = try? NSAttributedString(data: string, options: options, documentAttributes: nil)
            return attr?.string
        }
        return self?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
}
