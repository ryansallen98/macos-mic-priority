import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let model = MicrophoneModel()
  private var statusItem: NSStatusItem!
  private var popover: NSPopover!
  private var settingsPanel: NSPanel?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    configurePopover()
    configureStatusItem()
    model.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    model.stop()
  }

  private func configureStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    guard let button = statusItem.button else { return }
    button.image = NSImage(
      systemSymbolName: "mic.fill", accessibilityDescription: "macOS Mic Priority")
    button.image?.isTemplate = true
    button.toolTip = "macOS Mic Priority"
    button.target = self
    button.action = #selector(togglePopover)
  }

  private func configurePopover() {
    popover = NSPopover()
    popover.behavior = .transient
    popover.animates = true
    popover.contentViewController = NSHostingController(rootView: ContentView(model: model))
  }

  @objc private func togglePopover() {
    guard let button = statusItem.button else { return }

    if let settingsPanel, settingsPanel.isVisible {
      settingsPanel.close()
      return
    }

    if popover.isShown {
      popover.performClose(nil)
      return
    }

    model.refreshSystemState()
    let clickedScreen = screen(containing: NSEvent.mouseLocation)
    let statusItemScreen = button.window?.screen
    let contentHeight = preferredContentHeight(on: clickedScreen ?? statusItemScreen)

    // Menu-bar managers can render a status item on a different display than the
    // private NSStatusItem window. In that case NSPopover uses the wrong screen
    // and may be clipped, so present a normal floating settings panel instead.
    if let clickedScreen, statusItemScreen?.frame != clickedScreen.frame {
      showSettingsPanel(on: clickedScreen, contentHeight: contentHeight)
      return
    }

    popover.contentSize = NSSize(width: 390, height: contentHeight)
    popover.contentViewController = NSHostingController(
      rootView: ContentView(model: model, contentHeight: contentHeight))
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
  }

  private func showSettingsPanel(on screen: NSScreen, contentHeight: CGFloat) {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 390, height: contentHeight),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.title = "macOS Mic Priority"
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isFloatingPanel = true
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.moveToActiveSpace, .transient]
    panel.delegate = self
    panel.contentViewController = NSHostingController(
      rootView: ContentView(model: model, contentHeight: contentHeight))

    let visible = screen.visibleFrame
    let mouseX = NSEvent.mouseLocation.x
    let x = min(max(mouseX - 195, visible.minX + 8), visible.maxX - 398)
    panel.setFrameTopLeftPoint(NSPoint(x: x, y: visible.maxY - 8))

    settingsPanel = panel
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  private func preferredContentHeight(on screen: NSScreen?) -> CGFloat {
    let availableHeight = (screen?.visibleFrame.height ?? 610) - 24
    return max(240, min(570, availableHeight))
  }

  private func screen(containing point: NSPoint) -> NSScreen? {
    NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
  }

  func windowWillClose(_ notification: Notification) {
    if notification.object as? NSPanel === settingsPanel {
      settingsPanel = nil
    }
  }

  func windowDidResignKey(_ notification: Notification) {
    if notification.object as? NSPanel === settingsPanel {
      settingsPanel?.close()
    }
  }
}
