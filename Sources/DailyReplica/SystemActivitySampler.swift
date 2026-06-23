import AppKit
import ApplicationServices
import DailyReplicaCore
import Foundation
import IOKit

struct SystemActivitySampler {
    private let idleClassifier: IdleClassifier
    private let chromeURLReader = ChromeURLReader()

    init(idleThreshold: TimeInterval) {
        idleClassifier = IdleClassifier(threshold: idleThreshold)
    }

    func sample(now: Date, accessibilityTrusted: Bool) -> FocusSample {
        let app = NSWorkspace.shared.frontmostApplication
        let idleTime = Self.systemIdleTime()
        let state = idleClassifier.state(forIdleTime: idleTime)
        let appBundleID = app?.bundleIdentifier
        let windowTitle = accessibilityTrusted ? AccessibilityWindowReader.focusedWindowTitle(pid: app?.processIdentifier) : nil
        let urlString = appBundleID == "com.google.Chrome" ? chromeURLReader.activeURL() : nil

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

enum PermissionService {
    static func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

enum AccessibilityWindowReader {
    static func focusedWindowTitle(pid: pid_t?) -> String? {
        guard let pid else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let focusedWindow else {
            return nil
        }

        var titleValue: CFTypeRef?
        let windowElement = focusedWindow as! AXUIElement
        guard AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleValue) == .success else {
            return nil
        }
        return titleValue as? String
    }
}

struct ChromeURLReader {
    func activeURL() -> String? {
        let source = """
        tell application "Google Chrome"
            if (count of windows) is 0 then return ""
            return URL of active tab of front window
        end tell
        """
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else {
            return nil
        }
        let value = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
