import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Equatable, Sendable {
  let id: AudioObjectID
  let uid: String
  let name: String
  let transportType: UInt32
  let isDefault: Bool

  var isBuiltIn: Bool {
    transportType == kAudioDeviceTransportTypeBuiltIn
  }

  var transportName: String {
    switch transportType {
    case kAudioDeviceTransportTypeBuiltIn: "Built-in"
    case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: "Bluetooth"
    case kAudioDeviceTransportTypeUSB: "USB"
    case kAudioDeviceTransportTypeDisplayPort: "DisplayPort"
    case kAudioDeviceTransportTypeHDMI: "HDMI"
    case kAudioDeviceTransportTypeAirPlay: "AirPlay"
    case kAudioDeviceTransportTypeAggregate: "Aggregate"
    case kAudioDeviceTransportTypeVirtual: "Virtual"
    default: "Audio device"
    }
  }
}

struct StoredMicrophone: Codable, Equatable, Identifiable, Sendable {
  let uid: String
  var name: String

  var id: String { uid }
}
