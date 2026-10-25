import Foundation

/// The record a rich note belongs to. Comments attach to the same owner.
enum NoteOwner {
    case study(StudyEntry)
    case service(Service)
    case personal(PersonalNote)
    /// A sermon or Bible class inside a service (its notes and comments).
    case servicePart(ServicePart)
}
