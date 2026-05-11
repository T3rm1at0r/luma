import Foundation
import Observation

@Observable
@MainActor
final class TargetPicker {
    var context: TargetPickerContext?
}
