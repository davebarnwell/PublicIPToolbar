//
//  PublicIPHelperApp.swift
//  PublicIPHelper
//
//  Created by Dave Barnwell on 07/10/2024.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Path to the main app (adjust the path to point to the main app in its bundle)
        let mainAppBundlePath = Bundle.main.bundlePath as NSString
        let components = mainAppBundlePath.pathComponents
        
        // Navigate up to find the main app bundle (adjust the index according to the helper app's location)
        let pathToMainApp = NSString.path(withComponents: Array(components[0...(components.count - 5)])) // Adjust the `-5` based on your app structure
        
        let mainAppURL = URL(fileURLWithPath: pathToMainApp)
        
        // Use the modern API to launch the main app
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { (app, error) in
            if let error = error {
                print("Error launching main app: \(error.localizedDescription)")
            } else {
                print("Successfully launched main app")
            }
        }

        // Terminate the helper app
        NSApp.terminate(nil)
    }
}

