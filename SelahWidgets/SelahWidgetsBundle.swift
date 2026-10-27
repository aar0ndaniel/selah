import SwiftUI
import WidgetKit

@main
struct SelahWidgetsBundle: WidgetBundle {
    init() {
        WidgetFonts.register()
    }

    var body: some Widget {
        VerseWidget()
        StreakWidget()
        MoodWidget()
    }
}
