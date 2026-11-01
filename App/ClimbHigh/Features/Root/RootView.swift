import SwiftUI

enum AppTab: Hashable {
    case today, reminders, workout, notes, assistant
}

/// The five tabs. Each tab owns its own navigation stack.
struct RootView: View {
    @State private var selection: AppTab = DemoMode.initialTab
    @Environment(WorkoutController.self) private var workout
    @Environment(FaithStore.self) private var faith

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "sun.max.fill", value: AppTab.today) {
                NavigationStack { TodayView(selection: $selection) }
            }
            Tab("Reminders", systemImage: "bell.fill", value: AppTab.reminders) {
                NavigationStack { RemindersView() }
            }
            Tab("Workout", systemImage: "dumbbell.fill", value: AppTab.workout) {
                NavigationStack { WorkoutView() }
            }
            .badge(workout.isRestOver ? Text("!") : nil)
            Tab("Notes", systemImage: "note.text", value: AppTab.notes) {
                NavigationStack { NotesView() }
            }
            Tab("Pip", systemImage: "sparkles", value: AppTab.assistant) {
                NavigationStack { AssistantView() }
            }
        }
        .tint(Palette.accent)
        .onChange(of: workout.isRestOver) { _, isOver in
            if isOver { selection = .workout }
        }
        .sheet(isPresented: Binding(
            get: { faith.celebratingMilestone != nil },
            set: { if !$0 { faith.celebratingMilestone = nil } }
        )) {
            MilestoneCelebration(days: faith.celebratingMilestone ?? 0)
                .presentationDetents([.medium])
        }
    }
}
