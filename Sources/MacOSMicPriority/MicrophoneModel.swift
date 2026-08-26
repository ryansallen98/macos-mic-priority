import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class MicrophoneModel: ObservableObject {
  @Published private(set) var devices: [AudioDevice] = []
  @Published private(set) var preferences: [StoredMicrophone] = []
  @Published private(set) var statusText = "Starting…"
  @Published private(set) var lastError: String?
  @Published private(set) var launchAtLogin = false
  @Published private(set) var loginRequiresApproval = false
  @Published var isEnabled: Bool {
    didSet {
      persist()
      scheduleReconcile(reason: "Protection setting changed")
    }
  }

  var currentDevice: AudioDevice? { devices.first(where: \.isDefault) }
  var availableUnrankedDevices: [AudioDevice] {
    let ranked = Set(preferences.map(\.uid))
    return devices.filter { !ranked.contains($0.uid) }
  }

  private let audio: CoreAudioService
  private let store: PreferencesStoring
  private var reconcileTask: Task<Void, Never>?
  private var isSwitchInProgress = false
  private var hasCompletedSetup: Bool

  init(audio: CoreAudioService = CoreAudioService(), store: PreferencesStoring = PreferencesStore())
  {
    self.audio = audio
    self.store = store
    let saved = store.load()
    self.isEnabled = saved.isEnabled
    self.preferences = Self.deduplicated(saved.microphones)
    self.hasCompletedSetup = saved.hasCompletedSetup
  }

  func start() {
    refreshLoginStatus()
    do {
      try audio.startMonitoring { [weak self] in
        Task { @MainActor [weak self] in
          self?.scheduleReconcile(reason: "Audio configuration changed")
        }
      }
    } catch {
      lastError = error.localizedDescription
    }
    scheduleReconcile(reason: "App started", delay: .zero)
  }

  func stop() {
    reconcileTask?.cancel()
    audio.stopMonitoring()
  }

  func addPreference(_ device: AudioDevice) {
    guard !preferences.contains(where: { $0.uid == device.uid }) else { return }
    preferences.append(StoredMicrophone(uid: device.uid, name: device.name))
    hasCompletedSetup = true
    persist()
    scheduleReconcile(reason: "Priority list changed", delay: .zero)
  }

  func makeTopPriority(_ device: AudioDevice) {
    preferences.removeAll { $0.uid == device.uid }
    preferences.insert(StoredMicrophone(uid: device.uid, name: device.name), at: 0)
    hasCompletedSetup = true
    persist()
    scheduleReconcile(reason: "Preferred microphone changed", delay: .zero)
  }

  func removePreference(at index: Int) {
    guard preferences.indices.contains(index) else { return }
    preferences.remove(at: index)
    persist()
    scheduleReconcile(reason: "Priority list changed", delay: .zero)
  }

  func movePreference(from index: Int, by offset: Int) {
    let destination = index + offset
    guard preferences.indices.contains(index), preferences.indices.contains(destination) else {
      return
    }
    preferences.swapAt(index, destination)
    persist()
    scheduleReconcile(reason: "Priority order changed", delay: .zero)
  }

  func selectOnce(_ device: AudioDevice) {
    isEnabled = false
    Task { await switchTo(device, reason: "Selected manually while protection was paused") }
  }

  func refreshSystemState() {
    refreshLoginStatus()
    scheduleReconcile(reason: "Menu opened", delay: .zero)
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      lastError = nil
    } catch {
      lastError = "Could not update Launch at Login: \(error.localizedDescription)"
    }
    refreshLoginStatus()
  }

  func openSoundSettings() {
    guard
      let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension?input")
    else { return }
    NSWorkspace.shared.open(url)
  }

  func openLoginItemsSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
    else { return }
    NSWorkspace.shared.open(url)
  }

  func dismissError() {
    lastError = nil
  }

  private func scheduleReconcile(reason: String, delay: Duration = .milliseconds(250)) {
    reconcileTask?.cancel()
    reconcileTask = Task { [weak self] in
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled else { return }
      await self?.reconcile(reason: reason)
    }
  }

  private func reconcile(reason: String) async {
    do {
      devices = try audio.microphones()
      updateStoredNames()

      if !hasCompletedSetup, preferences.isEmpty, let current = currentDevice {
        preferences = [StoredMicrophone(uid: current.uid, name: current.name)]
        hasCompletedSetup = true
        persist()
      }

      guard isEnabled else {
        statusText = "Protection paused"
        lastError = nil
        return
      }
      guard
        let target = PriorityPolicy.preferredDevice(
          priorityUIDs: preferences.map(\.uid), availableDevices: devices
        )
      else {
        statusText = "Waiting for a preferred microphone"
        lastError = nil
        return
      }
      guard !target.isDefault else {
        statusText = "Protected: \(target.name)"
        lastError = nil
        return
      }
      guard !isSwitchInProgress else { return }
      await switchTo(target, reason: reason)
    } catch {
      lastError = error.localizedDescription
      statusText = "Unable to read microphones"
    }
  }

  private func switchTo(_ device: AudioDevice, reason: String) async {
    isSwitchInProgress = true
    defer { isSwitchInProgress = false }

    for attempt in 1...3 {
      do {
        try audio.setDefaultInputDevice(device.id)
        try await Task.sleep(for: .milliseconds(120 * attempt))
        devices = try audio.microphones()
        if devices.first(where: { $0.uid == device.uid })?.isDefault == true {
          statusText = "Protected: \(device.name)"
          lastError = nil
          return
        }
      } catch {
        if attempt == 3 {
          lastError = "Could not select \(device.name): \(error.localizedDescription)"
        }
      }
    }
    statusText = "Switch to \(device.name) did not stick"
    if lastError == nil {
      lastError = "macOS did not keep \(device.name) selected after three attempts (\(reason))."
    }
  }

  private func updateStoredNames() {
    let names = devices.reduce(into: [String: String]()) { result, device in
      result[device.uid] = device.name
    }
    let updated = preferences.map { stored in
      StoredMicrophone(uid: stored.uid, name: names[stored.uid] ?? stored.name)
    }
    if updated != preferences {
      preferences = updated
      persist()
    }
  }

  private func persist() {
    store.save(
      SavedPreferences(
        isEnabled: isEnabled,
        microphones: preferences,
        hasCompletedSetup: hasCompletedSetup
      ))
  }

  private func refreshLoginStatus() {
    let status = SMAppService.mainApp.status
    launchAtLogin = status == .enabled
    loginRequiresApproval = status == .requiresApproval
  }

  private static func deduplicated(_ microphones: [StoredMicrophone]) -> [StoredMicrophone] {
    var seen = Set<String>()
    return microphones.filter { seen.insert($0.uid).inserted }
  }
}
