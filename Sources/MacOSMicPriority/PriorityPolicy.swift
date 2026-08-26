import Foundation

enum PriorityPolicy {
  static func preferredDevice(
    priorityUIDs: [String],
    availableDevices: [AudioDevice]
  ) -> AudioDevice? {
    let devicesByUID = availableDevices.reduce(into: [String: AudioDevice]()) { result, device in
      if result[device.uid] == nil {
        result[device.uid] = device
      }
    }
    return priorityUIDs.lazy.compactMap { devicesByUID[$0] }.first
  }
}
