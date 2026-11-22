import Foundation

/// Run with ZOHAR_SELFTEST=1 — builds a small show, records cues and checks the DMX output.
@MainActor
enum SelfTest {
    static func run() -> Int32 {
        var failures = 0
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            print((ok ? "PASS " : "FAIL ") + name + (detail.isEmpty ? "" : " — " + detail))
            if !ok { failures += 1 }
        }

        let c = Console()
        c.show = Show()
        c.addFixtures(profileID: "builtin.drgbws", count: 4, startNumber: 1, name: "Par", universe: 1, address: 1, makeGroup: true)
        c.addFixtures(profileID: "builtin.spot", count: 2, startNumber: 10, name: "Spot", universe: 1, address: 100, makeGroup: true)
        c.addFixtures(profileID: "builtin.rgb", count: 1, startNumber: 20, name: "Bar", universe: 2, address: 1, makeGroup: false)
        check("patch", c.show.fixtures.count == 7 && c.show.groups.count == 2)
        check("no conflicts", c.conflicts().isEmpty)

        func dmx() -> [Int: [UInt8]] { c.buildDMX(c.render(c.now)) }

        // defaults
        var u = dmx()
        check("spot pan default 128", u[1]?[99] == 128, "\(u[1]?[99] ?? 0)")
        check("spot shutter default 255", u[1]?[105] == 255, "\(u[1]?[105] ?? 0)")
        check("dark at start", u[1]?[0] == 0)

        // programmer: pars red full
        c.selection = [1, 2, 3, 4]
        c.set(.dimmer, 1)
        c.setColor(r: 1, g: 0, b: 0)
        u = dmx()
        check("programmer dimmer", u[1]?[0] == 255)
        check("programmer red", u[1]?[1] == 255 && u[1]?[2] == 0)

        // record and play back
        c.record(toSlot: 0)
        check("cuelist recorded", c.show.cuelists.count == 1)
        c.clearProgrammer()
        c.clearProgrammer()
        u = dmx()
        check("cleared", u[1]?[0] == 0)
        guard let id = c.show.cuelists.first?.id else { return 1 }
        c.buttonDown(id)
        c.buttonUp(id)
        u = dmx()
        check("playback on", u[1]?[0] == 255 && u[1]?[1] == 255, "\(u[1]?[0] ?? 0)")

        // grand master & blackout
        c.grandMaster = 0.5
        u = dmx()
        check("grand master 50%", (126...129).contains(Int(u[1]?[0] ?? 0)), "\(u[1]?[0] ?? 0)")
        c.grandMaster = 1
        c.blackout = true
        u = dmx()
        check("blackout", u[1]?[0] == 0)
        c.blackout = false

        // toggle off
        c.buttonDown(id)
        c.buttonUp(id)
        u = dmx()
        check("playback off", u[1]?[0] == 0)

        // fader playback at 40%
        c.assignFader(0, .cuelist(id))
        c.setFader(0, 0.4)
        u = dmx()
        check("fader 40%", (100...104).contains(Int(u[1]?[0] ?? 0)), "\(u[1]?[0] ?? 0)")
        c.setFader(0, 0)
        u = dmx()
        check("fader to 0 releases", u[1]?[0] == 0)

        // virtual dimmer on RGB bar (no dimmer channel)
        c.selection = [20]
        c.setColor(r: 0, g: 1, b: 0)
        u = dmx()
        check("rgb bar dark without dimmer", u[2]?[1] == 0)
        c.set(.dimmer, 1)
        u = dmx()
        check("rgb bar green with virtual dimmer", u[2]?[1] == 255 && u[2]?[0] == 0)
        c.clearProgrammer(); c.clearProgrammer()

        // 2-step chase effect
        c.selection = [1, 2, 3, 4]
        c.addEffect(.dimChase, bpm: 60, size: 1, spread: 1, steps: 2)
        u = dmx()
        let row: [UInt8] = u[1] ?? []
        let d: [UInt8] = row.count >= 19 ? [row[0], row[6], row[12], row[18]] : [0, 0, 0, 0]
        check("2-step chase alternates", (d[0] == d[2]) && (d[1] == d[3]) && (d[0] != d[1]), "\(d)")
        c.clearProgrammer(); c.clearProgrammer()

        // position circle stays in range
        c.selection = [10, 11]
        c.set(.dimmer, 1)
        c.addEffect(.circle, bpm: 30, size: 1, spread: 0.5, steps: 2)
        u = dmx()
        check("circle moves pan", u[1]?[99] != 128 || u[1]?[101] != 128)

        // Art-Net poll reply parsing (8-port node, ports 0-3)
        var reply = [UInt8](repeating: 0, count: 239)
        for (i, ch) in Array("Art-Net".utf8).enumerated() { reply[i] = ch }
        reply[9] = 0x21
        reply[10] = 2; reply[11] = 0; reply[12] = 0; reply[13] = 50
        for (i, ch) in Array("NODE8".utf8).enumerated() { reply[26 + i] = ch }
        reply[173] = 4
        for i in 0..<4 { reply[174 + i] = 0x80; reply[190 + i] = UInt8(i) }
        let node = ArtNetDiscovery.parseReply(reply)
        check("artpoll reply", node?.ip == "2.0.0.50" && node?.universes == [0, 1, 2, 3] && node?.name == "NODE8", "\(String(describing: node))")

        // color matrix layer
        c.clearProgrammer(); c.clearProgrammer()
        if let g = c.show.groups.first {
            c.toggleGroupColor(g.id, 6)   // Blue
            c.selection = []
            if let id2 = c.show.cuelists.first?.id { c.activate(id2) }
            u = dmx()
            check("color matrix blue", u[1]?[3] == 255 && u[1]?[1] == 0, "\(u[1]?[1] ?? 0)/\(u[1]?[3] ?? 0)")
        }

        // save/load round trip
        let data = try? JSONEncoder().encode(c.show)
        let back = data.flatMap { try? JSONDecoder().decode(Show.self, from: $0) }
        check("save/load", back?.cuelists.first?.cues.first?.values[1]?[.red] == 1)

        print(failures == 0 ? "ALL TESTS PASSED" : "\(failures) TEST(S) FAILED")
        return failures == 0 ? 0 : 1
    }
}
