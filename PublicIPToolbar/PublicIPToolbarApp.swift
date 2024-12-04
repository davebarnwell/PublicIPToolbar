// PublicIPToolbarApp.swift

import SwiftUI
import Combine
import ServiceManagement
import Network

@main
struct PublicIPToolbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView() // No visible window needed
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private var formattedIPAddress: String = "Loading..."
    private var fullIP4Address: String = "Loading..."
    private var fullIP6Address: String = "Loading..."
    private var fullIP4MenuItem: NSMenuItem!
    private var fullIP6MenuItem: NSMenuItem!
    private var ipRefreshTimer: Timer?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)
    private let helperAppBundleIdentifier = "uk.co.freshsauce.PublicIPHelper"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()
        updateLoginItemState()
        monitorNetworkConnectivity()
        updatePublicIP()
        startIPRefreshTimer()
    }
    
    // MARK: - Status Item Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = formattedIPAddress
    }
    
    // MARK: - Menu Setup
    
    private func setupMenu() {
        let menu = NSMenu()
        
        fullIP4MenuItem = NSMenuItem(
            title: "Public 4: \(fullIP4Address)",
            action: #selector(copyIPv4ToClipboard),
            keyEquivalent: ""
        )
        fullIP4MenuItem.target = self
        menu.addItem(fullIP4MenuItem)
        
        fullIP6MenuItem = NSMenuItem(
            title: "Public 6: \(fullIP6Address)",
            action: #selector(copyIPv6ToClipboard),
            keyEquivalent: ""
        )
        fullIP6MenuItem.target = self
        menu.addItem(fullIP6MenuItem)
        
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "a"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(updatePublicIP), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "l"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // MARK: - Public IP Fetching
    
    @objc private func updatePublicIP() {
        fetchIPAddress(from: "https://api.ipify.org?format=json") { [weak self] ip in
            guard let self = self else { return }
            self.fullIP4Address = ip
            self.updateMenuItem(self.fullIP4MenuItem, with: "Public 4: \(ip)")
        }
        
        fetchIPAddress(from: "https://api6.ipify.org?format=json") { [weak self] ip in
            guard let self = self else { return }
            self.fullIP6Address = ip
            self.updateMenuItem(self.fullIP6MenuItem, with: "Public 6: \(ip)")
            self.updateStatusItem(with: ip)
        }
    }
    
    private func fetchIPAddress(from urlString: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: IPAddress.self, decoder: JSONDecoder())
            .map(\.ip)
            .replaceError(with: "Error")
            .receive(on: RunLoop.main)
            .sink(receiveValue: completion)
            .store(in: &cancellables)
    }
    
    private func updateMenuItem(_ menuItem: NSMenuItem, with title: String) {
        DispatchQueue.main.async {
            menuItem.title = title
        }
    }
    
    private func updateStatusItem(with ip: String) {
        DispatchQueue.main.async {
            self.formattedIPAddress = self.formatIPAddress(ip)
            self.statusItem?.button?.title = self.formattedIPAddress
        }
    }
    
    // MARK: - Copy to Clipboard
    
    @objc private func copyIPv4ToClipboard() {
        copyToClipboard(ip: fullIP4Address)
    }
    
    @objc private func copyIPv6ToClipboard() {
        copyToClipboard(ip: fullIP6Address)
    }
    
    private func copyToClipboard(ip: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ip, forType: .string)
    }
    
    // MARK: - Network Monitoring
    
    private func monitorNetworkConnectivity() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self.updatePublicIP()
                } else {
                    self.statusItem?.button?.title = "No Network"
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    // MARK: - Timer
    
    private func startIPRefreshTimer() {
        ipRefreshTimer?.invalidate()
        ipRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updatePublicIP()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatIPAddress(_ ipAddress: String) -> String {
        if ipAddress.contains(":") {
            let components = ipAddress.split(separator: ":")
            if let first = components.first, let last = components.last {
                return "\(first):...\(last)"
            }
        }
        return ipAddress
    }
    
    @objc private func toggleLoginItem() {
        let appService = SMAppService.loginItem(identifier: helperAppBundleIdentifier)
        do {
            if appService.status == .enabled {
                try appService.unregister()
            } else {
                try appService.register()
            }
            updateLoginItemState()
        } catch {
            print("Failed to toggle login item: \(error)")
        }
    }
    
    private func updateLoginItemState() {
        let appService = SMAppService.loginItem(identifier: helperAppBundleIdentifier)
        if let menu = statusItem?.menu, let loginItem = menu.item(withTitle: "Start at Login") {
            loginItem.state = appService.status == .enabled ? .on : .off
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Public IP Toolbar"
        alert.informativeText = """
        Displays your current public IP address in the menu bar.
        Created by Dave Barnwell.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(self)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ipRefreshTimer?.invalidate()
        monitor.cancel()
    }
}

struct IPAddress: Decodable {
    let ip: String
}
