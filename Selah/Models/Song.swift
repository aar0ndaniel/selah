import Foundation
import SwiftData

@Model
final class Song {
    var hymnNumber: String = ""
    var title: String = ""
    var order: Int = 0
    var service: Service?

    init(hymnNumber: String = "", title: String = "", order: Int = 0) {
        self.hymnNumber = hymnNumber
        self.title = title
        self.order = order
    }
}
