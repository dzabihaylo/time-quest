import Foundation
import SwiftData

typealias TaskEstimation = TimeQuestSchemaV5.TaskEstimation

extension TaskEstimation {
    /// Computed rating from stored raw value. Falls back to .way_off if invalid.
    var rating: AccuracyRating {
        AccuracyRating(rawValue: ratingRawValue) ?? .way_off
    }
}
