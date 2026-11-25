/// Operating system of the device.
struct OSContext: Hashable, Sendable, Encodable {
    let name: String
    let version: String
    let build: String?
}
