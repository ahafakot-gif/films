import CoreMIDI
import Foundation

enum MIDIKind: String, Codable { case note, cc }

enum MIDITarget: Codable, Hashable {
    case button(page: Int, slot: Int)
    case fader(Int)
    case grandMaster
    case blackout
}

struct MIDIMap: Codable, Hashable, Identifiable {
    var id = UUID()
    var kind: MIDIKind
    var channel: UInt8
    var number: UInt8
    var target: MIDITarget
}

struct MIDIMessage {
    var kind: MIDIKind
    var channel: UInt8
    var number: UInt8
    var value: UInt8
    /// note on (velocity > 0) or CC > 63
    var isOn: Bool { kind == .note ? value > 0 : value > 63 }
}

/// Listens to every connected MIDI controller.
final class MIDIInput {
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var connected: [MIDIEndpointRef] = []
    var onMessage: ((MIDIMessage) -> Void)?
    private(set) var sourceNames: [String] = []

    func start() {
        let status = MIDIClientCreateWithBlock("Zohar" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.connectAll() }
        }
        guard status == noErr else { return }
        MIDIInputPortCreateWithBlock(client, "Zohar in" as CFString, &port) { [weak self] list, _ in
            self?.parse(list)
        }
        connectAll()
    }

    func connectAll() {
        for src in connected { MIDIPortDisconnectSource(port, src) }
        connected.removeAll()
        sourceNames.removeAll()
        for i in 0..<MIDIGetNumberOfSources() {
            let src = MIDIGetSource(i)
            if MIDIPortConnectSource(port, src, nil) == noErr {
                connected.append(src)
                var name: Unmanaged<CFString>?
                if MIDIObjectGetStringProperty(src, kMIDIPropertyDisplayName, &name) == noErr, let n = name?.takeRetainedValue() {
                    sourceNames.append(n as String)
                }
            }
        }
    }

    private func parse(_ list: UnsafePointer<MIDIPacketList>) {
        var messages: [MIDIMessage] = []
        for packet in list.unsafeSequence() {
            let len = Int(packet.pointee.length)
            let bytes: [UInt8] = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(len)) }
            var i = 0
            while i < bytes.count {
                let st = bytes[i]
                let type = st & 0xF0
                guard type == 0x80 || type == 0x90 || type == 0xB0 else { i += 1; continue }
                guard i + 2 < bytes.count else { break }
                let ch = st & 0x0F
                let d1 = bytes[i + 1], d2 = bytes[i + 2]
                switch type {
                case 0x90: messages.append(MIDIMessage(kind: .note, channel: ch, number: d1, value: d2))
                case 0x80: messages.append(MIDIMessage(kind: .note, channel: ch, number: d1, value: 0))
                default: messages.append(MIDIMessage(kind: .cc, channel: ch, number: d1, value: d2))
                }
                i += 3
            }
        }
        guard !messages.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            for m in messages { self?.onMessage?(m) }
        }
    }
}
