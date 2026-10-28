//
//  AppOrientation.swift
//  cascade
//
//  Created by Codex on 5/31/26.
//

import SwiftUI

#if os(iOS)
import UIKit

final class AppOrientationDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }
}

enum AppOrientation {
    static func lock(_ orientation: UIInterfaceOrientationMask) {
        AppOrientationDelegate.orientationLock = orientation
        UIViewController.attemptRotationToDeviceOrientation()
    }
}
#else
final class AppOrientationDelegate: NSObject {}

enum AppOrientation {
    static func lock(_ orientation: Any) {}
}
#endif
