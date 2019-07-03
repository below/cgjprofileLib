/*
 * cgjprofile :- A tool to analyze the validity of iOS mobileprovision
 *               files and associated certificates
 * Copyright (c) 2019, Alexander von Below, Deutsche Telekom AG
 * contact: opensource@telekom.de
 * This file is distributed under the conditions of the MIT license.
 * For details see the file LICENSE on the toplevel.
 */

import Foundation

/// A wrapper for `Mobileprovision` to allow formatted output
public class PrettyProvision: Mobileprovision {

    var markExpired = true
    var warnDays = 30
    
    public var formatter: DateFormatter = { let new = DateFormatter(); new.dateStyle = .short; new.timeStyle = .short; return new}()
    
    /**
     Prints the contents of a `Mobileprovision` object with a format
     - Parameter format: A format string with C-Style placeholders
     - Parameter warnDays: If present, the number of days a profile/certificate must still be valid
     
     Output is sent to stdout
     
     The placeholders for the format string are:
     * %e ExpirationDate
     * %c CreationDate
     * %u UUID
     * %a AppIDName
     * %t TeamName
     * %n Name
     
     Minimum width specifiers can be used, such as "%40u", adding spaces until the minimum length is met.
     If no format string is provided, the default is "%u %t %n"
     */
    public func print(format: String = "%u %t %n", warnDays: Int? = nil) {
        if let warnDays = warnDays, warnDays > 0 {
            self.warnDays = warnDays
        }
        fputs (parsedOutput(format)+"\n", stdout)
    }

    /**
     Returns contents of a `Mobileprovision` object with a format
     - Parameter format: A format string with C-Style placeholders
     
     The placeholders for the format string are:
     * %e ExpirationDate
     * %c CreationDate
     * %u UUID
     * %a AppIDName
     * %t TeamName
     * %n Name
     
     Minimum width specifiers can be used, such as "%40u", adding spaces until the minimum length is met.
     If no format string is provided, the default is "%u %t %n"
     
     The `warnDays` instance variable can be set before
     */
    public func parsedOutput(_ format: String) -> String {
        var output = ""
        var index = format.startIndex
        while (index < format.endIndex) {
            var result : String
            (result, index) = parseNonFormatString(fromString: format, startIndex: index)
            output.append(result)
            guard index < format.endIndex else {
                break
            }
            (result, index) = parseFormat(fromString: format, startIndex:index)
            output.append(result)
        }
        return output
    }
    
    fileprivate func parseNonFormatString(fromString string: String, startIndex : String.Index) -> (String, String.Index) {
        var index = startIndex
        var output = "";

        guard index < string.endIndex else {
            return (output, index)
        }
        var input = string[index]
        while input != "%" {
            output.append(input)
            index = string.index(after: index)
            guard index < string.endIndex else {
                break
            }
            input = string[index]
        }
        return (output, index)
    }
    
    fileprivate func parseFormat(fromString string: String, startIndex : String.Index) -> (String, String.Index) {
        var index = startIndex
        guard index < string.endIndex else {
            return ("", index)
        }
        var input = string[index]
        guard input == "%" else {
            return ("", index)
        }
        index = string.index(after: index)
        guard index < string.endIndex else {
            return ("", index)
        }
        input = string[index]

        if input == "%" {
            index = string.index(after: index)
            return ("%", index)
        }
        else {
            var number : Int = 0
            (number, index) = parseInteger(fromString: string, startIndex: index)
            guard index < string.endIndex else {
                return ("", index)
            }
            input = string[index]
            var value = self.value(forFormat: input)
            if number > value.count {
                let padding = number - value.count
                for _ in 0 ..< padding {
                    value.append(" ")
                }
            }
            index = string.index(after: index)
            return (value, index)
        }
    }

    fileprivate func value(forFormat input: Character) -> String {
        switch input {
        case "e":
            var output = formatter.string(from: self.expirationDate)
            if markExpired {
                let days = self.daysToExpiration
                let ANSI_COLOR_RED = "\u{001b}[31m"
                let ANSI_COLOR_GREEN = "\u{001b}[32m"
                let ANSI_COLOR_YELLOW = "\u{001b}[33m"
                let ANSI_COLOR_RESET = "\u{001b}[0m"
                var color = ANSI_COLOR_GREEN
                if days <= 0 {
                    color = ANSI_COLOR_RED
                }
                else if days < warnDays {
                    color = ANSI_COLOR_YELLOW
                }
                output.insert(contentsOf: color, at: output.startIndex)
                output.append(ANSI_COLOR_RESET)
            }
            return output
        case "c":
            return formatter.string(from: self.creationDate)
        case "u":
            return self.uuid
        case "a":
            return self.appIDName
        case "t":
            return self.teamName
        case "n":
            return self.name
        default:
            return ""
        }
    }
    
    fileprivate func parseInteger(fromString string: String, startIndex: String.Index) -> (Int, String.Index) {
        var numberString : String = ""
        var index = startIndex
        guard index < string.endIndex else {
            return (0, index)
        }
        var input = string[index]
        while "0123456789".contains(input) {
            numberString.append(input)
            index = string.index(after: index)
            guard index < string.endIndex else {
                break
            }
            input = string[index]
        }
        let number = Int(numberString)
        return (number ?? 0, index)
    }
}

