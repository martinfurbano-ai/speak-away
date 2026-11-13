import Foundation

/// Whether the on-device brain (Apple Intelligence) can be used right now.
/// No API key is ever involved: it is either on this device or not available.
public enum BrainAvailability: Equatable, Sendable {
    case available
    /// Version 26 of the system and an eligible device, but Apple Intelligence is switched off.
    case needsAppleIntelligence
    /// A system older than version 26, or an SDK without the framework.
    case unsupportedOS
    /// This device cannot run Apple Intelligence (for example, not Apple Silicon).
    case deviceNotEligible
    /// Apple Intelligence is on but the model is still downloading.
    case modelNotReady

    public var isUsable: Bool { self == .available }

    /// Spanish text for the interface, worded so it reads right on the Mac and on the iPhone.
    /// Empty when the brain is available.
    public var message: String {
        switch self {
        case .available: return ""
        case .needsAppleIntelligence: return "Activa Apple Intelligence en los ajustes de tu dispositivo para usar esta función, sin claves ni cuentas."
        case .unsupportedOS: return "Esta función necesita la versión 26 del sistema o una más reciente, con Apple Intelligence."
        case .deviceNotEligible: return "Este dispositivo no es compatible con Apple Intelligence."
        case .modelNotReady: return "Apple Intelligence todavía está preparando su modelo. Inténtalo de nuevo en unos minutos."
        }
    }
}

public enum BrainError: Error, Equatable, LocalizedError, Sendable {
    case unavailable(BrainAvailability)
    case tooLong
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let a): return a.message
        case .tooLong: return "El texto es demasiado largo para el modelo del dispositivo."
        case .failed(let why): return why
        }
    }
}
