import Foundation

/// Training calculations, as pure functions over stored data.
///
/// Nothing here is persisted — volume is recomputed from the sets every time it
/// is shown. That keeps a single source of truth: editing an old set changes
/// every figure derived from it, with no cache to go stale.
///
/// These are free functions rather than methods on the models so that tests,
/// widgets, and a future watch app can all call them without a `ModelContext`.
enum TrainingMath {
    /// Total weight moved: the sum of weight × reps over completed sets.
    /// Warm-ups are excluded — they are a ramp-up, not training load.
    static func volume(of sets: [SetEntry]) -> Double {
        sets
            .filter(\.countsTowardStats)
            .reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    static func volume(of session: WorkoutSession) -> Double {
        session.orderedExercises.reduce(0) { $0 + volume(of: $1.orderedSets) }
    }

    /// Number of completed working sets in a session. Warm-ups do not count.
    static func completedSetCount(of session: WorkoutSession) -> Int {
        session.orderedExercises.reduce(0) { $0 + $1.orderedSets.count(where: \.countsTowardStats) }
    }

    /// Estimated one-rep max using the Epley formula: `w × (1 + reps / 30)`.
    ///
    /// One number that captures both ways of getting stronger — more weight, or
    /// more reps at the same weight — which is what makes it usable as a single
    /// personal-record measure.
    ///
    /// Caveat worth knowing: Epley is only reliable to roughly 12 reps. Beyond
    /// that it overestimates, so a 20-rep burnout set can look like a record it
    /// is not. Left uncapped deliberately, because silently clamping would
    /// misreport what you actually lifted.
    static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double {
        guard weightKg > 0, reps > 0 else { return 0 }
        guard reps > 1 else { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }

    static func estimatedOneRepMax(of set: SetEntry) -> Double {
        estimatedOneRepMax(weightKg: set.weightKg, reps: set.reps)
    }

    /// Heaviest single set performed, ignoring reps.
    static func topSetWeight(of performed: SessionExercise) -> Double {
        performed.workingSets.map(\.weightKg).max() ?? 0
    }

    /// Best estimated 1RM across the exercise's completed sets.
    static func bestOneRepMax(of performed: SessionExercise) -> Double {
        performed.workingSets.map(estimatedOneRepMax(of:)).max() ?? 0
    }

    static func volume(of performed: SessionExercise) -> Double {
        volume(of: performed.orderedSets)
    }
}

/// What to plot on an exercise's progress chart.
///
/// Three metrics rather than one because they answer different questions: top
/// weight is what you can lift, estimated 1RM accounts for reps too, and volume
/// tracks total work — which can rise even in a week where neither of the others
/// moves.
enum ProgressMetric: String, CaseIterable, Identifiable {
    case topWeight
    case oneRepMax
    case volume

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topWeight: "Top Set"
        case .oneRepMax: "Est. 1RM"
        case .volume: "Volume"
        }
    }

    /// Value in canonical units (kilograms) for one performance.
    func value(for performed: SessionExercise) -> Double {
        switch self {
        case .topWeight: TrainingMath.topSetWeight(of: performed)
        case .oneRepMax: TrainingMath.bestOneRepMax(of: performed)
        case .volume: TrainingMath.volume(of: performed)
        }
    }
}
