//
//  PublicIPToolbarApp.swift
//  PublicIPToolbar
//
//  Created by Dave Barnwell on 05/10/2024.
//

import SwiftUI
import Combine
import ServiceManagement
import Network

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
    var fullIPAddress: String = "Loading..."  // Store the full IP address separately
    var fullIPMenuItem: NSMenuItem! // Menu item for showing the full IP address
    var ipRefreshTimer: Timer?
    let monitor = NWPathMonitor() // Network path monitor for checking connectivity
    let queue = DispatchQueue.global(qos: .background) // Run network monitor on a background queue
    
    let helperAppBundleIdentifier = "uk.co.freshsauce.PublicIPHelper"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item with a variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = currentIPAddress
        }
        
        // Create the menu
        let menu = NSMenu()
        // Add the full IP address at the top of the menu
        fullIPMenuItem = NSMenuItem(title: "Public IP: \(fullIPAddress)", action: nil, keyEquivalent: "")
        menu.addItem(fullIPMenuItem)
        
        menu.addItem(NSMenuItem.separator()) // Add a separator after the full IP
        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "a"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Copy IP Address", action: #selector(copyIPAddressToClipboard), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(callUpdatePublicIP), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "l"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        updateLoginItemState()
        
        // Start monitoring network connectivity
        monitorNetworkConnectivity()
        
        updatePublicIP()
        startIPRefreshTimer()  // Only start the timer once
    }
    
    func monitorNetworkConnectivity() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return } // Safely unwrap `self`
            if path.status == .satisfied {
                self.updatePublicIP()
            } else {
                self.statusItem?.button?.title = "No Network"
            }
        }
        monitor.start(queue: queue)
    }
    
    func updatePublicIP() {
        // Fetch the public IP address using an IP check service
        let url = URL(string: "https://api64.ipify.org?format=json")!
        
        cancellable?.cancel()  // Cancel any previous subscriptions
        
        //        print("Updating public IP...")
        // Create a URLRequest with a cache policy to ignore cached data
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: IPAddress.self, decoder: JSONDecoder())
            .replaceError(with: IPAddress(ip: "Error"))
            .receive(on: RunLoop.main)
            .sink { [weak self] ipAddress in
                guard let self = self else { return } // Safely unwrap `self`
                // Store the full IP address for copying later
                // Update full IP and status item
                self.fullIPAddress = ipAddress.ip
                self.fullIPMenuItem.title = "Public IP: \(self.fullIPAddress)"
                self.currentIPAddress = self.formatIPAddress(ipAddress.ip)
                self.statusItem?.button?.title = self.currentIPAddress
                //                print("IP address: \(self?.fullIPAddress ?? "Error")")
            }
    }
    
    func startIPRefreshTimer() {
        ipRefreshTimer?.invalidate()  // Ensure any previous timer is invalidated
        ipRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60 * 5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updatePublicIP()
        }
    }

    
    func formatIPAddress(_ ipAddress: String) -> String {
        // Check if the address is IPv6 (contains colons)
        if ipAddress.contains(":") {
            let components = ipAddress.split(separator: ":")
            if components.count > 1 {
                // Return the first and last section of the IPv6 address
                return "\(components[0]):\(components[1]):...:\(components.last!)"
            }
        }
        // If it's not IPv6, return the address as-is
        return ipAddress
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
        let currentYear = Calendar.current.component(.year, from: Date())
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        alert.messageText = "Public IP Toolbar"
        alert.informativeText = "Version \(version ?? "?.?")\nDisplays your current public IP address in the menu bar.\nCopyright © \(currentYear) Dave Barnwell"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func copyIPAddressToClipboard() {
        // Copy the full IP address (not the shortened one)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullIPAddress, forType: .string)
    }
        
    func applicationWillTerminate(_ notification: Notification) {
        ipRefreshTimer?.invalidate()
        cancellable?.cancel()
        monitor.cancel()  // Cancel network path monitor
    }
    
    @objc func quitApp() {
        cancellable?.cancel()  // Cancel any ongoing subscription
        NSApplication.shared.terminate(self)
    }
    
}

struct IPAddress: Decodable {
    let ip: String
}

