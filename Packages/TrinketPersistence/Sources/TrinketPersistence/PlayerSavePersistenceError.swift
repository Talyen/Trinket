import Foundation

public enum PlayerSavePersistenceError: Error, Equatable, Sendable {
    case writeFailed
    case invalidSave(String)
    case storeUnavailable(String)

    /// Single mapping from commit errors to persistence state. Typed save
    /// errors pass through so diagnostics and retry gating keep their cause;
    /// only truly unknown failures collapse to parameterless `writeFailed`.
    static func mapped(_ error: Error) -> Self {
        (error as? Self) ?? .writeFailed
    }

    /// Failures worth a silent background retry: generic writes plus temporary
    /// store outages (including the in-memory fallback). Validation failures
    /// (`.invalidSave`) never retry — retrying a rejection cannot heal it.
    var isRetryable: Bool {
        switch self {
        case .writeFailed, .storeUnavailable:
            true
        case .invalidSave:
            false
        }
    }
}
