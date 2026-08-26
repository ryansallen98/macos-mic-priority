@preconcurrency import CoreAudio
import Foundation

enum CoreAudioError: LocalizedError {
  case osStatus(OSStatus, operation: String)
  case missingProperty(String)

  var errorDescription: String? {
    switch self {
    case .osStatus(let status, let operation):
      let code = Self.fourCharacterCode(status)
      return "\(operation) failed (\(code), \(status))."
    case .missingProperty(let property):
      return "Core Audio did not provide \(property)."
    }
  }

  private static func fourCharacterCode(_ status: OSStatus) -> String {
    let value = UInt32(bitPattern: status)
    let bytes = [24, 16, 8, 0].map { UInt8((value >> UInt32($0)) & 0xff) }
    guard bytes.allSatisfy({ $0 >= 32 && $0 < 127 }) else { return "OSStatus" }
    return "'" + String(bytes: bytes, encoding: .ascii)! + "'"
  }
}

final class CoreAudioService: @unchecked Sendable {
  typealias ChangeHandler = @Sendable () -> Void

  private let listenerQueue = DispatchQueue(label: "dev.rallen.macos-mic-priority.core-audio")
  private var deviceListener: AudioObjectPropertyListenerBlock?
  private var defaultListener: AudioObjectPropertyListenerBlock?

  func microphones() throws -> [AudioDevice] {
    let defaultID = try defaultInputDeviceID()
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    try check(
      AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
      ), operation: "Reading audio device list size")

    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    var ids = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: count)
    try check(
      AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids
      ), operation: "Reading audio device list")

    return ids.compactMap { id in
      guard hasInputStreams(deviceID: id),
        let uid = stringProperty(deviceID: id, selector: kAudioDevicePropertyDeviceUID),
        let name = stringProperty(deviceID: id, selector: kAudioObjectPropertyName)
      else { return nil }

      return AudioDevice(
        id: id,
        uid: uid,
        name: name,
        transportType: uint32Property(deviceID: id, selector: kAudioDevicePropertyTransportType)
          ?? 0,
        isDefault: id == defaultID
      )
    }
    .sorted { lhs, rhs in
      if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
      if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }

  func defaultInputDeviceID() throws -> AudioObjectID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var id = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    try check(
      AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id
      ), operation: "Reading the default microphone")
    return id
  }

  func setDefaultInputDevice(_ id: AudioObjectID) throws {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var mutableID = id
    let size = UInt32(MemoryLayout<AudioObjectID>.size)
    try check(
      AudioObjectSetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &mutableID
      ), operation: "Selecting the default microphone")
  }

  func startMonitoring(onChange: @escaping ChangeHandler) throws {
    stopMonitoring()

    var devicesAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let devicesBlock: AudioObjectPropertyListenerBlock = { _, _ in onChange() }
    try check(
      AudioObjectAddPropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject), &devicesAddress, listenerQueue, devicesBlock
      ), operation: "Monitoring connected microphones")
    deviceListener = devicesBlock

    var defaultAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let defaultBlock: AudioObjectPropertyListenerBlock = { _, _ in onChange() }
    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject), &defaultAddress, listenerQueue, defaultBlock
    )
    guard status == noErr else {
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject), &devicesAddress, listenerQueue, devicesBlock
      )
      deviceListener = nil
      throw CoreAudioError.osStatus(status, operation: "Monitoring the default microphone")
    }
    defaultListener = defaultBlock
  }

  func stopMonitoring() {
    if let block = deviceListener {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject), &address, listenerQueue, block
      )
      deviceListener = nil
    }

    if let block = defaultListener {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject), &address, listenerQueue, block
      )
      defaultListener = nil
    }
  }

  deinit {
    stopMonitoring()
  }

  private func hasInputStreams(deviceID: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: kAudioDevicePropertyScopeInput,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr,
      size >= UInt32(MemoryLayout<AudioBufferList>.size)
    else { return false }

    let pointer = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer { pointer.deallocate() }
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer) == noErr else {
      return false
    }

    let list = UnsafeMutableAudioBufferListPointer(
      pointer.assumingMemoryBound(to: AudioBufferList.self))
    return list.contains { $0.mNumberChannels > 0 }
  }

  private func stringProperty(deviceID: AudioObjectID, selector: AudioObjectPropertySelector)
    -> String?
  {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var unmanagedValue: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &unmanagedValue) == noErr,
      let value = unmanagedValue?.takeUnretainedValue()
    else {
      return nil
    }
    return value as String
  }

  private func uint32Property(deviceID: AudioObjectID, selector: AudioObjectPropertySelector)
    -> UInt32?
  {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else {
      return nil
    }
    return value
  }

  private func check(_ status: OSStatus, operation: String) throws {
    guard status == noErr else { throw CoreAudioError.osStatus(status, operation: operation) }
  }
}
