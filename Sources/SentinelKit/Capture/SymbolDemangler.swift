import Foundation

/// Turns mangled Swift symbols (`$s4Shop…`) into readable names using the Swift runtime's own `swift_demangle`.
enum SymbolDemangler {

    // MARK: - Types

    private typealias Demangle = @convention(c) (
        UnsafePointer<CChar>?,
        Int,
        UnsafeMutablePointer<CChar>?,
        UnsafeMutablePointer<Int>?,
        UInt32
    ) -> UnsafeMutablePointer<CChar>?

    // MARK: - Constants

    /// Address of `swift_demangle`, looked up once. Kept as an integer so the constant is `Sendable`; the handle of
    /// the main program from `dlopen(nil)` stays valid for the whole process, so it is never closed.
    private static let demangleAddress: UInt? = {
        guard let handle = dlopen(nil, RTLD_NOW), let symbol = dlsym(handle, "swift_demangle") else {
            return nil
        }

        return UInt(bitPattern: symbol)
    }()

    // MARK: - Methods

    /// The readable name, or the symbol itself when it is not a Swift symbol.
    static func demangle(_ symbol: String) -> String {
        guard let address = demangleAddress, let pointer = UnsafeRawPointer(bitPattern: address) else {
            return symbol
        }

        let demangle = unsafeBitCast(pointer, to: Demangle.self)

        guard let result = symbol.withCString({ demangle($0, strlen($0), nil, nil, 0) }) else {
            return symbol
        }

        defer {
            free(result)
        }

        return String(cString: result)
    }
}
