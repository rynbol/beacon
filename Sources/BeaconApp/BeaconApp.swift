import SwiftUI
import BeaconKit

@main
struct BeaconApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @NSApplicationDelegateAdaptor(NotificationDelegate.self) private var delegate

    private var model: TaskListModel { delegate.model }

    var body: some Scene {
        WindowGroup {
            TaskListView(model: model)
                .task {
                    // The harness modes are handled in the app delegate, which
                    // runs whether or not a window ever appears.
                    guard !E2ECheck.isHarnessRun else { return }
                    await model.start()
                }
                // A single, committed look: white surface, monochrome ink.
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.refresh(); await CalendarModel.shared.refresh() } }
                }
                .task {
                    guard !model.isPreview, !E2ECheck.isHarnessRun else { return }
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(60)) } catch { break }
                        await model.refresh()
                        if scenePhase == .active {
                            await CalendarModel.shared.refresh(requestSourceRefresh: false)
                        }
                    }
                }
        }
        .defaultSize(width: 1000, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh") {
                    Task { await model.refresh(); await CalendarModel.shared.refresh() }
                }
                .keyboardShortcut("r")
            }
        }
    }
}
