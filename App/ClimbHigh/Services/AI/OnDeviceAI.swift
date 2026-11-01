import Foundation
import FoundationModels

/// Whether Apple's on-device model can be used right now.
///
/// The model runs entirely on the iPhone: free, private, works offline.
/// It needs Apple Intelligence turned on (Settings → Apple Intelligence & Siri).
enum AIStatus: Equatable {
    case ready
    case turnedOff
    case downloading
    case unsupported

    static var current: AIStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(.appleIntelligenceNotEnabled):
            return .turnedOff
        case .unavailable(.modelNotReady):
            return .downloading
        case .unavailable:
            return .unsupported
        @unknown default:
            return .unsupported
        }
    }

    var isReady: Bool { self == .ready }

    var message: String {
        switch self {
        case .ready: "On-device AI is ready."
        case .turnedOff: "Turn on Apple Intelligence in iPhone Settings → Apple Intelligence & Siri to use the AI features."
        case .downloading: "Apple Intelligence is still downloading. AI features will work once it finishes."
        case .unsupported: "On-device AI isn't available on this iPhone. Voice commands still work."
        }
    }
}

/// Turns AI errors into short, human sentences.
enum AIErrorText {
    static func describe(_ error: Error) -> String {
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .exceededContextWindowSize:
                return "That's more text than the on-device AI can handle at once. Try a shorter note or start a new chat."
            case .guardrailViolation:
                return "The on-device AI declined to respond to that one."
            case .assetsUnavailable:
                return AIStatus.current.message
            default:
                return "The on-device AI couldn't finish that. Try again in a moment."
            }
        }
        return error.localizedDescription
    }
}
