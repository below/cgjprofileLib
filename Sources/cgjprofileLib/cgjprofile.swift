/*
 * cgjprofile :- A tool to analyze the validity of iOS mobileprovision
 *               files and associated certificates
 * Copyright (c) 2019, Alexander von Below, Deutsche Telekom AG
 * contact: opensource@telekom.de
 * This file is distributed under the conditions of the MIT license.
 * For details see the file LICENSE on the toplevel.
 */

import Foundation
import Darwin

public final class CgjProfileCore {
    
    enum CgjProfileError : Error {
        case regexInvalid(String)
    }
    
    static var mobileProvisionURL: URL = {
        let fm = FileManager.default
        let librayURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return librayURL.appendingPathComponent("MobileDevice/Provisioning Profiles")
    }()
    
    static let mobileprovisionExtension = "mobileprovision"

    static func profilePaths (paths: [String]? = nil) -> [String] {
        
        let urls = try! FileManager.default.contentsOfDirectory(at: self.mobileProvisionURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
        return urls.map({ (url) -> String in
            url.path
        })
    }
    
    static func profileURL (path: String) throws -> URL {
        let fm = FileManager.default
        var url : URL! = URL(fileURLWithPath: path)
        if !fm.fileExists(atPath: url.path) {
            url = mobileProvisionURL.appendingPathComponent(path)
        }
        if !fm.fileExists(atPath: url.path) {
            url = url.appendingPathExtension(mobileprovisionExtension)
        }
        if !fm.fileExists(atPath: url.path) {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: [NSFilePathErrorKey:path])
        }
        return url
    }
    
    internal static func foundInRegularExpression (_ regEx: NSRegularExpression?, provision: Mobileprovision) -> Bool {
        if let regExParser = regEx {
            var searchString: String = provision.appIDName + provision.teamName + provision.name
            for team in provision.teamIdentifier {
                searchString.append(team)
            }
            for certificate in provision.developerCertificates {
                do {
                    searchString.append(try certificate.displayName())
                } catch {
                }
            }
            let range: NSRange = NSRange(searchString.startIndex..<searchString.endIndex, in: searchString)
            if regExParser.firstMatch(in: searchString, options: [], range: range) == nil {
                return false
            }
        }
        return true
    }
    
    /**
        Analyzes Mobile Provisioning Profiles and their corresponding certificates
        - Parameter format: A format string with C-Style placeholders
        - Parameter pathsUDIDsOrNames: The paths of the files to analyze, or their UDIDs. If not present, the default location on macOS is used
        - Parameter warnDays: If present, the number of days a profile/certificate must still be valid
        - Parameter quietArg: If true, the function will produce minimal output
        - Parameter regEx: A regular expression. Optional, if present, only certificates which match this in any part of their decodable text will be processed
        - Parameter deletionHandler: If present, this closure will be called to confirm the deletion of the profiles in the argument. Profiles will be listed with the same format parameters
        - Returns: EXIT_SUCCESS or EXIT_ERROR
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

    public static func analyzeMobileProfiles (format formatArgument: String?, pathsUDIDsOrNames: [String]? = nil, regEx: String? = nil, warnDays: Int? = nil, quiet quietArg: Bool? = false, deletionHandler: ((_ profiles: [String]) -> Bool)? = nil) throws -> Int32 {
        
        struct ProfileInfo {
            var provision: PrettyProvision
            var path: String
        }
        
        let format: String = formatArgument ?? "%u %t %n"
        var result = EXIT_SUCCESS
        var regExParser: NSRegularExpression?
        
        if let regEx = regEx {
            do {
            regExParser = try NSRegularExpression(pattern: regEx, options: .caseInsensitive)
            } catch {
                throw CgjProfileError.regexInvalid(regEx)
            }
        }
        
        let workingPaths : [String] = pathsUDIDsOrNames ?? CgjProfileCore.profilePaths()
        let quiet = quietArg ?? false
        
        let identityCertificates = try Mobileprovision.identityCertificates()
        var profilesScheduledForDeletion = [ProfileInfo]()
        
        for path in workingPaths {
            var url: URL! = URL(fileURLWithPath: path)
            if url == nil {
                url = CgjProfileCore.mobileProvisionURL.appendingPathComponent(path)
            }
            if let provision = PrettyProvision(url: url) {
                
                if !foundInRegularExpression(regExParser, provision: provision) {
                    continue
                }
                
                if !quiet {
                    provision.print(format: format, warnDays:warnDays)
                }
                
                let daysToExpiration = provision.daysToExpiration
                if daysToExpiration <= 0 {
                    
                    profilesScheduledForDeletion.append(ProfileInfo(provision: provision, path: path))
                    
                    let description = "\(ANSI_COLOR_RED)ERROR: \(provision.uuid) \(provision.name) is expired\(ANSI_COLOR_RESET)\n"
                    fputs(description, stderr)
                    result = EXIT_FAILURE
                } else if let warnDays = warnDays, daysToExpiration <= warnDays {
                    let description = "\(ANSI_COLOR_YELLOW)WARNING: \(provision.uuid) will expire in \(daysToExpiration) days\(ANSI_COLOR_RESET)\n"
                    fputs(description, stderr)
                }
                
                // Stop checking if the certificate is expired anyway
                guard result == EXIT_SUCCESS else {
                    continue
                }
                
                var validCertificateFound = false
                for certificate in provision.developerCertificates {
                    do {
                        
                        let certName = try certificate.displayName()
                        if let exisitingCertificate = identityCertificates[certName], exisitingCertificate == certificate {
                            
                            let date = try certificate.enddate()
                            let daysToExpiration = Mobileprovision.daysTo(date: date)
                            
                            if daysToExpiration <= 0 {
                                let description = "\(ANSI_COLOR_YELLOW)WARNING: \(provision.uuid) \(provision.name) certificate \(certName) is expired\(ANSI_COLOR_RESET)\n"
                                fputs(description, stderr)
                            } else {
                                
                                validCertificateFound = true
                                
                                if let warnDays = warnDays, daysToExpiration <= warnDays {
                                    let description = "\(ANSI_COLOR_YELLOW)WARNING: \(provision.uuid) certificate \(certName) will expire in \(daysToExpiration) days\(ANSI_COLOR_RESET)\n"
                                    fputs(description, stderr)
                                }
                            }
                        }
                        else {
                            let description = "\(ANSI_COLOR_YELLOW)WARNING: \(provision.uuid) \(provision.name) certificate \(certName) is not present in keychain\(ANSI_COLOR_RESET)\n"
                            fputs(description, stderr)
                        }
                    }
                    catch {
                        throw error
                    }
                }
                if !validCertificateFound {
                    result = EXIT_FAILURE
                    let description = "\(ANSI_COLOR_RED)ERROR: \(provision.uuid) \(provision.name) No valid certificates found\(ANSI_COLOR_RESET)\n"
                    fputs(description, stderr)
                    
                }
            }
            else {
                let output = "Error decoding \(url?.absoluteString ?? "No URL")\n"
                fputs(output, stderr)
            }
        }
        
        if profilesScheduledForDeletion.count > 0 {
            let names = profilesScheduledForDeletion.map { (profileInfo) -> String in
                profileInfo.provision.parsedOutput(format)
            }
            if let handler = deletionHandler, handler(names) == true {
                print ("Deleting:")
                let fileManager = FileManager.default
                for profileInfo in profilesScheduledForDeletion {
                    do {
                        try fileManager.removeItem(atPath: profileInfo.path)
                        print (profileInfo.path)
                    } catch {
                        print ("Unable to remove \(profileInfo.path)")
                    }
                }
            }
        }
        
        return result
    }
}

