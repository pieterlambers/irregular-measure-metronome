import SwiftUI

@main
struct IrregularMeasureMetronomeApp: App {
    @StateObject private var metronome = MetronomeModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(metronome)
        }
    }
}
