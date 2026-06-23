import AppKit
import ApplicationServices
import DailyReplicaCore
import Foundation
import IOKit

struct SystemActivitySampler: ActivitySampling {
    private let idleClassifier: IdleClassifier
    private let browserURLReader = BrowserURLReader()

    init(idleThreshold: TimeInterval) {
        idleClassifier = IdleClassifier(threshold: idleThreshold)
    }

    func sample(now: Date, accessibilityTrusted _: Bool) -> FocusSample {
        let app = NSWorkspace.shared.frontmostApplication
        let idleTime = Self.systemIdleTime()
        let state = idleClassifier.state(forIdleTime: idleTime)
        let appBundleID = app?.bundleIdentifier
        let windowTitle = AccessibilityWindowReader.focusedWindowTitle(pid: app?.processIdentifier)
        let urlString = browserURLReader.activeURL(for: appBundleID)

        return FocusSample(
            timestamp: now,
            state: state,
            appBundleID: appBundleID,
            appName: app?.localizedName,
            windowTitle: windowTitle,
            urlString: urlString
        )
    }

    private static func systemIdleTime() -> TimeInterval {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else {
            return 0
        }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any],
              let idleNanoseconds = dictionary["HIDIdleTime"] as? UInt64 else {
            return 0
        }
        return TimeInterval(idleNanoseconds) / 1_000_000_000
    }
}

struct AccessibilityPermissionChecker: PermissionChecking {
    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        if prompt {
            let options = ["AXTrustedCheckOptionPrompt": true]
            return AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
        return AXIsProcessTrustedWithOptions(nil)
    }
}

enum AccessibilityWindowReader {
    static func focusedWindowTitle(pid: pid_t?) -> String? {
        guard let pid else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(pid)
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            guard let window = elementAttribute(appElement, attribute) else {
                continue
            }
            if let title = title(of: window as! AXUIElement) {
                return title
            }
        }

        guard let windows = elementAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
            return nil
        }
        return windows.lazy.compactMap(title(of:)).first
    }

    private static func elementAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func title(of element: AXUIElement) -> String? {
        guard let title = elementAttribute(element, kAXTitleAttribute) as? String else {
            return nil
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct BrowserURLReader {
    struct BrowserDefinition: Identifiable, Hashable {
        let bundleID: String
        let applicationName: String
        let tabSpecifier: String

        var id: String { bundleID }

        var isInstalled: Bool {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        }
    }

    static let supportedBrowsers: [BrowserDefinition] = [
        BrowserDefinition(bundleID: "com.google.Chrome", applicationName: "Google Chrome", tabSpecifier: "active tab"),
        BrowserDefinition(bundleID: "com.apple.Safari", applicationName: "Safari", tabSpecifier: "current tab"),
        BrowserDefinition(bundleID: "com.brave.Browser", applicationName: "Brave Browser", tabSpecifier: "active tab"),
        BrowserDefinition(bundleID: "com.microsoft.edgemac", applicationName: "Microsoft Edge", tabSpecifier: "active tab"),
    ]

    private static let scriptTemplate = """
    tell application "%@"
        if (count of windows) is 0 then return ""
        return URL of %@ of front window
    end tell
    """

    private static func browserDefinition(for bundleID: String) -> BrowserDefinition? {
        supportedBrowsers.first { $0.bundleID == bundleID }
    }

    private static func scriptSource(for bundleID: String) -> String? {
        guard let source = browserDefinition(for: bundleID) else {
            return nil
        }
        return String(format: scriptTemplate, source.applicationName, source.tabSpecifier)
    }

    static func supports(bundleID: String?) -> Bool {
        guard let bundleID else {
            return false
        }
        return browserDefinition(for: bundleID) != nil && NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    func activeURL(for bundleID: String?) -> String? {
        guard let bundleID else {
            return nil
        }
        guard Self.supports(bundleID: bundleID),
              let source = Self.scriptSource(for: bundleID),
              let script = NSAppleScript(source: source) else {
            return nil
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else {
            return nil
        }
        let value = result.stringValue?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    func hasAutomationPermission(for bundleID: String) -> Bool {
        guard Self.supports(bundleID: bundleID),
              let source = Self.scriptSource(for: bundleID),
              let script = NSAppleScript(source: source) else {
            return false
        }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        guard error == nil else {
            if let errorNumber = error?[NSAppleScript.errorNumber] as? NSNumber {
                return errorNumber.intValue != -1743
            }
            return false
        }
        return true
    }

    func hasAnyAutomationPermission() -> Bool {
        Self.supportedBrowsers
            .filter { $0.isInstalled }
            .contains(where: { hasAutomationPermission(for: $0.bundleID) })
    }
}
