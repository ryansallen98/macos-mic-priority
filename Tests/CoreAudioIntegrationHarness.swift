import CoreAudio
import Foundation

@main
enum CoreAudioIntegrationHarness {
  static func main() throws {
    let service = CoreAudioService()
    let devices = try service.microphones()
    let command = CommandLine.arguments.dropFirst().first ?? "list"

    switch command {
    case "list":
      for device in devices {
        print("\(device.isDefault ? "*" : "-")\t\(device.uid)\t\(device.name)")
      }
    case "current-uid":
      guard let current = devices.first(where: \.isDefault) else { exit(2) }
      print(current.uid)
    case "switch-alternate":
      guard let current = devices.first(where: \.isDefault),
        let alternate = devices.first(where: { !$0.isDefault })
      else {
        print("At least two microphones are required.")
        exit(3)
      }
      try service.setDefaultInputDevice(alternate.id)
      print("ORIGINAL_UID=\(current.uid)")
      print("ALTERNATE_UID=\(alternate.uid)")
      print("ALTERNATE_NAME=\(alternate.name)")
    case "set":
      guard CommandLine.arguments.count == 3 else { exit(2) }
      let uid = CommandLine.arguments[2]
      guard let device = devices.first(where: { $0.uid == uid }) else { exit(3) }
      try service.setDefaultInputDevice(device.id)
    default:
      print("Usage: CoreAudioIntegrationHarness [list|current-uid|switch-alternate|set UID]")
      exit(2)
    }
  }
}
