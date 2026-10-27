import Foundation
import Testing
@testable import Selah

struct StudyTitleTests {
    @Test func displayTitleFallsBackToTheBookName() {
        let plan = ReadingPlan(bookName: "Isaiah", totalChapters: 66)
        #expect(plan.displayTitle == "Isaiah")
        plan.title = "   "
        #expect(plan.displayTitle == "Isaiah")
        plan.title = " Calling of mankind "
        #expect(plan.displayTitle == "Calling of mankind")
    }

    @Test func illustrationIsStoredAsItsRawValue() {
        let plan = ReadingPlan(bookName: "Psalms", totalChapters: 150)
        #expect(plan.illustration == nil)
        plan.illustration = .lamp
        #expect(plan.illustrationRaw == "lamp")
        #expect(plan.illustration == .lamp)
        plan.illustration = nil
        #expect(plan.illustrationRaw.isEmpty)
    }

    @Test func illustrationAssetNamesFollowTheImportScript() {
        #expect(StudyIllustration.sunrise.assetName == "Study-sunrise")
        #expect(StudyIllustration.allCases.count == 6)
    }
}
