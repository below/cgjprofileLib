// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

/*
 * cgjprofileLib :- A library to analyze the validity of iOS mobileprovision
 *                  files and associated certificates
 * Copyright (c) 2019, Alexander von Below, Deutsche Telekom AG
 * contact: opensource@telekom.de
 * This file is distributed under the conditions of the MIT license.
 * For details see the file LICENSE on the toplevel.
 */

import PackageDescription

let package = Package(
    name: "cgjprofileLib",
    products: [
        .library(name: "cgjprofileLib", targets: ["cgjprofileLib"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "cgjprofileLib"),
        .testTarget(
            name: "cgjprofileToolTests",
            dependencies: ["cgjprofileLib"]
        )
    ]
)
