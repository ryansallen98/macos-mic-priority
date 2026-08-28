import AppKit
import SwiftUI

struct ContentView: View {
  @ObservedObject var model: MicrophoneModel
  let contentHeight: CGFloat

  init(model: MicrophoneModel, contentHeight: CGFloat = 570) {
    self.model = model
    self.contentHeight = contentHeight
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          protectionCard
          prioritySection
          availableSection
          if let error = model.lastError {
            errorCard(error)
          }
        }
        .padding(16)
      }
      Divider()
      footer
    }
    .frame(width: 390, height: contentHeight)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(systemName: model.isEnabled ? "mic.fill" : "mic.slash")
        .font(.system(size: 25, weight: .semibold))
        .foregroundStyle(model.isEnabled ? .green : .secondary)
        .frame(width: 34)
      VStack(alignment: .leading, spacing: 2) {
        Text("Mic Priority")
          .font(.headline)
        Text(model.statusText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      Toggle("", isOn: $model.isEnabled)
        .toggleStyle(.switch)
        .labelsHidden()
        .help("Protect the highest available microphone in your priority list")
    }
    .padding(16)
  }

  private var protectionCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Current microphone", systemImage: "waveform")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(model.currentDevice?.name ?? "No input device detected")
        .font(.body.weight(.medium))
      Text("The first available microphone below is kept as the macOS default.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
  }

  private var prioritySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Priority", detail: "Highest available wins")
      if model.preferences.isEmpty {
        Text("Add a connected microphone to begin.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.vertical, 6)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(model.preferences.enumerated()), id: \.element.uid) { index, stored in
            priorityRow(stored, index: index)
            if index < model.preferences.count - 1 { Divider().padding(.leading, 34) }
          }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.separator.opacity(0.5)))
      }
    }
  }

  private func priorityRow(_ stored: StoredMicrophone, index: Int) -> some View {
    let connected = model.devices.first { $0.uid == stored.uid }
    return HStack(spacing: 9) {
      Text("\(index + 1)")
        .font(.caption.monospacedDigit().weight(.bold))
        .foregroundStyle(index == 0 ? .white : .secondary)
        .frame(width: 22, height: 22)
        .background(index == 0 ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
      VStack(alignment: .leading, spacing: 1) {
        Text(stored.name).lineLimit(1)
        Text(connected.map { $0.isDefault ? "Active" : $0.transportName } ?? "Not connected")
          .font(.caption2)
          .foregroundStyle(connected?.isDefault == true ? .green : .secondary)
      }
      Spacer()
      Button {
        model.movePreference(from: index, by: -1)
      } label: {
        Image(systemName: "chevron.up")
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Move \(stored.name) up")
      .disabled(index == 0)
      Button {
        model.movePreference(from: index, by: 1)
      } label: {
        Image(systemName: "chevron.down")
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Move \(stored.name) down")
      .disabled(index == model.preferences.count - 1)
      Button {
        model.removePreference(at: index)
      } label: {
        Image(systemName: "minus.circle")
      }
      .buttonStyle(.borderless)
      .foregroundStyle(.secondary)
      .accessibilityLabel("Remove \(stored.name)")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .contextMenu {
      if let connected {
        Button("Make Highest Priority") { model.makeTopPriority(connected) }
        Button("Select Now") { model.selectOnce(connected) }
      }
      Button("Remove", role: .destructive) { model.removePreference(at: index) }
    }
  }

  private var availableSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Available", detail: "Connected microphones")
      if model.availableUnrankedDevices.isEmpty {
        Text("All connected microphones are in your priority list.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(model.availableUnrankedDevices) { device in
          HStack {
            Image(systemName: device.isBuiltIn ? "laptopcomputer" : "mic")
              .foregroundStyle(.secondary)
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
              Text(device.name).lineLimit(1)
              Text(device.transportName).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Add") { model.addPreference(device) }
              .controlSize(.small)
          }
        }
      }
    }
  }

  private func sectionTitle(_ title: String, detail: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title).font(.subheadline.weight(.semibold))
      Spacer()
      Text(detail).font(.caption2).foregroundStyle(.secondary)
    }
  }

  private func errorCard(_ message: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
      Text(message).font(.caption).textSelection(.enabled)
      Spacer(minLength: 4)
      Button {
        model.dismissError()
      } label: {
        Image(systemName: "xmark")
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Dismiss error")
    }
    .padding(10)
    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
  }

  private var footer: some View {
    VStack(spacing: 8) {
      HStack {
        Toggle(
          "Launch at Login",
          isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
          )
        )
        .toggleStyle(.checkbox)
        Spacer()
        Button("Sound Settings…") { model.openSoundSettings() }
          .buttonStyle(.borderless)
      }
      if model.loginRequiresApproval {
        HStack {
          Text("Launch at Login needs approval in System Settings.")
            .font(.caption2).foregroundStyle(.secondary)
          Spacer()
          Button("Open") { model.openLoginItemsSettings() }
            .buttonStyle(.link).font(.caption2)
        }
      }
      HStack {
        Text("Version \(appVersion) · No audio is recorded or transmitted.")
          .font(.caption2).foregroundStyle(.tertiary)
        Spacer()
        Button("Quit") { NSApplication.shared.terminate(nil) }
          .buttonStyle(.borderless)
      }
    }
    .padding(12)
  }

  private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "Development"
  }
}
