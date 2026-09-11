//
//  Distribution.swift
//  RuleKit
//
//  MIT License
//
//  Copyright (c) 2023 Thomas Durand
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

extension RuleKit {
    /// How the running build was installed.
    ///
    /// Some triggers only make sense for a build the public actually downloaded: an App
    /// Store review prompt shown to a TestFlight tester, or to yourself in the simulator,
    /// is a prompt wasted — the review sheet does nothing outside of an App Store install.
    /// Gate those triggers with ``Rule/appStoreBuild`` or ``Rule/distribution(_:)``.
    public enum Distribution: Sendable, Hashable, CaseIterable {
        /// Installed from the App Store, the only channel where a review prompt counts.
        case appStore
        /// Installed from TestFlight.
        case testFlight
        /// Anything else: the simulator, a build run from Xcode, an ad-hoc or enterprise
        /// install, a Developer ID app, or a platform with no App Store at all.
        case other

        /// The channel the running build came from.
        ///
        /// Resolved once, the first time it is read: an install cannot change channel
        /// while the app runs. When the channel cannot be told apart, this is ``other``,
        /// so a gated trigger stays silent rather than firing where it does not belong.
        public static let current: Distribution = resolve()

        private static func resolve() -> Distribution {
            #if targetEnvironment(simulator)
            // The review sheet, and every other store affordance, is a no-op here.
            return .other
            #elseif canImport(Darwin)
            // An embedded profile means the build was signed for development, ad-hoc or
            // enterprise distribution. The App Store strips it from what it delivers.
            if hasEmbeddedProvisioningProfile {
                return .other
            }
            if receiptExists(named: "sandboxReceipt") {
                return .testFlight
            }
            #if os(macOS) || targetEnvironment(macCatalyst)
            // A Mac App Store install always carries its receipt, so its absence rules
            // the App Store out (a Developer ID app, or one run straight from Xcode).
            return receiptExists(named: "receipt") ? .appStore : .other
            #else
            // On iOS and its siblings nothing else positively identifies an App Store
            // install, so treat what the checks above did not rule out as one. Erring
            // this way keeps a real install prompting; erring the other way would
            // silence every trigger in production, where it is hardest to notice.
            return .appStore
            #endif
            #else
            // Linux, Android: no App Store to be installed from.
            return .other
            #endif
        }

        #if canImport(Darwin)
        /// Whether the main bundle embeds a provisioning profile: at the root of an
        /// iOS-style bundle, under `Contents/` in a macOS-style one.
        private static var hasEmbeddedProvisioningProfile: Bool {
            ["embedded.mobileprovision", "Contents/embedded.provisionprofile"]
                .contains(where: bundleContains)
        }

        /// Whether the main bundle carries an App Store receipt under the given name:
        /// `receipt` for a production install, `sandboxReceipt` for a TestFlight one.
        /// The App Store stores it in `StoreKit/` in an iOS-style bundle, and in
        /// `Contents/_MASReceipt/` in a macOS-style one.
        private static func receiptExists(named name: String) -> Bool {
            ["StoreKit/\(name)", "Contents/_MASReceipt/\(name)"]
                .contains(where: bundleContains)
        }

        private static func bundleContains(_ path: String) -> Bool {
            FileManager.default.fileExists(
                atPath: Bundle.main.bundleURL.appendingPathComponent(path).path
            )
        }
        #endif
    }
}
