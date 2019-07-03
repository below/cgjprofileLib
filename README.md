# cgjprofileLib

A Swift Pacakge for macOS to analyse the validity of mobile provision files and the corresponding certificates. The software is well suited to be used in automated setups.

Let me know if this is useful, I am looking forward to your comments!

## Building

This is a Swift Package Manager project. To build, simply execute `swift build -c release`. To create an Xcode project for Xcode 10, execute `swift package generate-xcodeproj`. With Xcode 11 or later, you can simply open the `Package.swift`

For more information, see the [Package Manager documentation](https://swift.org/package-manager/)

## Usage

The library has three main components:

*  `class Mobileprovision`
This class encapsulates a mobile provisioning profile. Typically, you will want to instantiate it using ` init?(url: URL)`  or  `init?(data: Data)`.

*  `class PrettyProvision`
A subclass of for  `Mobileprovision` to allow pretty-printing the profile

* `class CgjProfileCore`
This class offers `func analyzeMobileProfiles`  to analyze and print profiles
 
