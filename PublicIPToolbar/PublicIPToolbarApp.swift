//
//  PublicIPToolbarApp.swift
//  PublicIPToolbar
//
//  Created by Dave Barnwell on 05/10/2024.
//

import SwiftUI
import Combine
import ServiceManagement

@main
struct PublicIPToolbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            // We don't actually need a visible window for a menu bar app
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var cancellable: AnyCancellable?
    var currentIPAddress: String = "Loading..."
    let helperAppBundleIdentifier = "uk.co.freshsauce.PublicIPHelper"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
         // Create the status bar item with a variable length
         statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
         
         if let button = statusItem?.button {
             button.title = currentIPAddress
         }
         
         // Create the menu with the "Copy IP Address" option
         let menu = NSMenu()
         menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "a"))
         menu.addItem(NSMenuItem.separator()) // Add a separator if you want more items later
         menu.addItem(NSMenuItem(title: "Copy IP Address", action: #selector(copyIPAddressToClipboard), keyEquivalent: "c"))
         menu.addItem(NSMenuItem(title: "Refresh", action: #selector(callUpdatePublicIP), keyEquivalent: "r"))
         menu.addItem(NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "l"))
         menu.addItem(NSMenuItem.separator()) // Add a separator if you want more items later
         menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

         statusItem?.menu = menu
         
         updatePublicIP()
    }
    
    func updatePublicIP() {
        // Fetch the public IP address using an IP check service
        let url = URL(string: "https://api64.ipify.org?format=json")!
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: IPAddress.self, decoder: JSONDecoder())
            .replaceError(with: IPAddress(ip: "Error"))
            .receive(on: RunLoop.main)
            .sink { [weak self] ipAddress in
                self?.currentIPAddress = ipAddress.ip
                self?.statusItem?.button?.title = ipAddress.ip
            }
        self.startIPRefreshTimer()
    }
    
    func startIPRefreshTimer() {
        Timer.scheduledTimer(withTimeInterval: 60 * 5, repeats: true) { _ in
            self.updatePublicIP()
        }
    }
    
    @objc func toggleLoginItem() {
        // Use SMAppService to manage login item
        let appService = SMAppService.loginItem(identifier: helperAppBundleIdentifier)

        if appService.status == .enabled {
            // If already enabled, disable the login item
            try? appService.unregister()
        } else {
            // If not enabled, enable the login item
            try? appService.register()
        }
        updateLoginItemState()
    }
    
    func updateLoginItemState() {
        let appService = SMAppService.loginItem(identifier: helperAppBundleIdentifier)
        if let menu = statusItem?.menu, let loginItem = menu.item(withTitle: "Start at Login") {
            loginItem.state = appService.status == .enabled ? .on : .off
        }
    }
    
    
    @objc func callUpdatePublicIP() {
        self.updatePublicIP()
    }

    @objc func showAbout() {
        // Display an "About" dialog
        let alert = NSAlert()
        alert.messageText = "Public IP Toolbar"
        alert.informativeText = "Version 1.0\nThis app displays your current public IP address in the menu bar.\nBy Dave Barnwell"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func copyIPAddressToClipboard() {
        // Copy the current IP address to the clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentIPAddress, forType: .string)
        
//        print("Copied IP to clipboard: \(currentIPAddress)")
    }

    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}

struct IPAddress: Decodable {
    let ip: String
}

