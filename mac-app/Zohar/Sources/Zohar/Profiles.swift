import Foundation

/// Generic starting profiles. Every one can be edited in Patch → Profiles
/// to match the exact DMX mode of a real fixture.
enum Profiles {
    static let builtins: [FixtureProfile] = [
        FixtureProfile(id: "builtin.dimmer", name: "Dimmer (1ch)", channels: [ChannelDef(.dimmer)]),
        FixtureProfile(id: "builtin.rgb", name: "LED RGB (3ch)", channels: [
            ChannelDef(.red), ChannelDef(.green), ChannelDef(.blue),
        ]),
        FixtureProfile(id: "builtin.rgbw", name: "LED RGBW (4ch)", channels: [
            ChannelDef(.red), ChannelDef(.green), ChannelDef(.blue), ChannelDef(.white),
        ]),
        FixtureProfile(id: "builtin.drgbws", name: "LED Par D-RGBW-Strobe (6ch)", channels: [
            ChannelDef(.dimmer), ChannelDef(.red), ChannelDef(.green), ChannelDef(.blue),
            ChannelDef(.white), ChannelDef(.strobe),
        ]),
        FixtureProfile(id: "builtin.rgbwauv", name: "LED Par RGBWA+UV (6ch)", channels: [
            ChannelDef(.red), ChannelDef(.green), ChannelDef(.blue),
            ChannelDef(.white), ChannelDef(.amber), ChannelDef(.uv),
        ]),
        FixtureProfile(id: "builtin.spot", name: "Moving Spot (16ch)", channels: [
            ChannelDef(.pan, 128), ChannelDef(.panFine), ChannelDef(.tilt, 128), ChannelDef(.tiltFine),
            ChannelDef(.ptSpeed), ChannelDef(.dimmer), ChannelDef(.shutter, 255),
            ChannelDef(.colorWheel), ChannelDef(.gobo), ChannelDef(.goboRot), ChannelDef(.prism),
            ChannelDef(.prismRot), ChannelDef(.focus, 128), ChannelDef(.zoom, 128), ChannelDef(.frost),
            ChannelDef(.control),
        ]),
        FixtureProfile(id: "builtin.beam", name: "Moving Beam (16ch)", channels: [
            ChannelDef(.colorWheel), ChannelDef(.shutter, 255), ChannelDef(.dimmer), ChannelDef(.gobo),
            ChannelDef(.prism), ChannelDef(.prismRot), ChannelDef(.frost), ChannelDef(.focus, 128),
            ChannelDef(.pan, 128), ChannelDef(.panFine), ChannelDef(.tilt, 128), ChannelDef(.tiltFine),
            ChannelDef(.ptSpeed), ChannelDef(.control), ChannelDef(.other), ChannelDef(.other),
        ]),
        FixtureProfile(id: "builtin.wash", name: "LED Wash Zoom RGBW (14ch)", channels: [
            ChannelDef(.pan, 128), ChannelDef(.panFine), ChannelDef(.tilt, 128), ChannelDef(.tiltFine),
            ChannelDef(.ptSpeed), ChannelDef(.dimmer), ChannelDef(.shutter, 255),
            ChannelDef(.red), ChannelDef(.green), ChannelDef(.blue), ChannelDef(.white),
            ChannelDef(.cto), ChannelDef(.zoom, 128), ChannelDef(.control),
        ]),
        FixtureProfile(id: "builtin.strobe", name: "Strobe (2ch: dim, rate)", channels: [
            ChannelDef(.dimmer), ChannelDef(.strobe),
        ]),
        FixtureProfile(id: "builtin.strobergb", name: "Strobe RGB (6ch)", channels: [
            ChannelDef(.dimmer), ChannelDef(.strobe), ChannelDef(.red), ChannelDef(.green),
            ChannelDef(.blue), ChannelDef(.white),
        ]),
    ]
}
