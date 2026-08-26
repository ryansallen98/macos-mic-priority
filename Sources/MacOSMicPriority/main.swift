import AppKit
import ServiceManagement

if CommandLine.arguments.contains("--unregister-login-item") {
  do {
    if SMAppService.mainApp.status != .notRegistered {
      try SMAppService.mainApp.unregister()
    }
    print("Launch at Login is disabled.")
    exit(EXIT_SUCCESS)
  } catch {
    fputs("Could not disable Launch at Login: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
  }
}

@MainActor
private func runApp() {
  let app = NSApplication.shared
  let delegate = AppDelegate()
  app.delegate = delegate
  withExtendedLifetime(delegate) {
    app.run()
  }
}

runApp()
