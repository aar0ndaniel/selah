import Foundation

/// The record a rich note belongs to. Comments attach to the same owner.
enum NoteOwner {
    case study(StudyEntry)
    case service(Service)
    case personal(PersonalNote)
}
