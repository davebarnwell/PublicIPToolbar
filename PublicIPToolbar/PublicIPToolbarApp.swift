import SwiftUI
import Combine
import ServiceManagement
import Network
import AppKit

@main
struct PublicIPToolbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
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
    private var countdownMenuItem: NSMenuItem!
    private var ipRefreshTimer: Timer?
    private var countdownTimer: Timer?
    private var remainingSeconds: Int = 300
    private let refreshInterval = 300
    private var startAtLoginMenuItem: NSMenuItem!
    private let helperBundleIdentifier = "com.yourcompany.PublicIPToolbarHelper"

    struct IPResponse: Codable {
        let ip: String
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()
        updatePublicIP()
        startIPRefreshTimer()
    }

    private func startIPRefreshTimer() {
        ipRefreshTimer?.invalidate()
        ipRefreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval), repeats: true) { [weak self] _ in
            self?.updatePublicIP()
            self?.startCountdownTimer()
        }
        startCountdownTimer()
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        remainingSeconds = refreshInterval
        countdownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateCountdown), userInfo: nil, repeats: true)
        RunLoop.current.add(countdownTimer!, forMode: .common)
    }

    @objc private func updateCountdown() {
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            updateCountdownMenuItem()
        }
    }

    private func updateCountdownMenuItem() {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        countdownMenuItem.title = String(format: "Next IP Refresh: %02d:%02d", minutes, seconds)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = formattedIPAddress
    }

    private func setupMenu() {
        let menu = NSMenu()
        
        fullIP4MenuItem = NSMenuItem(title: "Public 4: \(fullIP4Address)", action: #selector(copyIPv4ToClipboard), keyEquivalent: "")
        menu.addItem(fullIP4MenuItem)

        fullIP6MenuItem = NSMenuItem(title: "Public 6: \(fullIP6Address)", action: #selector(copyIPv6ToClipboard), keyEquivalent: "")
        menu.addItem(fullIP6MenuItem)
        
        menu.addItem(.separator())

        countdownMenuItem = NSMenuItem(title: "Next IP Refresh: 05:00", action: nil, keyEquivalent: "")
        menu.addItem(countdownMenuItem)
        
        menu.addItem(.separator())

        let refreshMenuItem = NSMenuItem(title: "Refresh IP now", action: #selector(refreshIPManually), keyEquivalent: "r")
        menu.addItem(refreshMenuItem)

        startAtLoginMenuItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        startAtLoginMenuItem.state = isStartAtLoginEnabled() ? .on : .off
        menu.addItem(startAtLoginMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdownMenuItem()
        }
    }

    @objc private func copyIPv4ToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullIP4Address, forType: .string)
    }

    @objc private func copyIPv6ToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullIP6Address, forType: .string)
    }

    @objc private func toggleStartAtLogin() {
        let appService = SMAppService.mainApp
        let isEnabled = appService.status == .enabled

        do {
            if isEnabled {
                try appService.unregister()
            } else {
                try appService.register()
            }
            startAtLoginMenuItem.state = isEnabled ? .off : .on
        } catch {
            print("Failed to toggle start at login: \(error)")
        }
    }

    private func isStartAtLoginEnabled() -> Bool {
        let appService = SMAppService.mainApp
        return appService.status == .enabled
    }

    @objc private func refreshIPManually() {
        updatePublicIP()
    }

    private func updatePublicIP() {
        fetchIPAddress(from: "https://api64.ipify.org?format=json") { ip in
            self.fullIP6Address = ip
            self.formattedIPAddress = self.formatIPv6Address(ip)
            self.updateMenuItems()
        }

        fetchIPAddress(from: "https://api.ipify.org?format=json") { ip in
            self.fullIP4Address = ip
            self.formattedIPAddress = ip
            self.updateMenuItems()
        }
    }

    private func fetchIPAddress(from urlString: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(IPResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(decoded.ip)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion("Error decoding IP")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion("Error fetching IP")
                }
            }
        }.resume()
    }

    private func updateMenuItems() {
        DispatchQueue.main.async {
            self.statusItem?.button?.title = self.formattedIPAddress
            self.fullIP4MenuItem.title = "Public 4: \(self.fullIP4Address)"
            self.fullIP6MenuItem.title = "Public 6: \(self.fullIP6Address)"
        }
    }

    private func formatIPv6Address(_ ipAddress: String) -> String {
        let components = ipAddress.split(separator: ":")
        if components.count > 2 {
            return "\(components.first!)::\(components.last!)"
        }
        return ipAddress
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
