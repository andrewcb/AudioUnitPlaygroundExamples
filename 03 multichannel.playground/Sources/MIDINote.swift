import Foundation
import AudioUnit


/// A MIDI note, with a duration; this generates a note-on and a note-off event
public struct MIDINote {
    public let pitch: UInt32 // 0..127
    public let velocity: UInt32 // 0..127
    public let channel: UInt32 // 0..15, technically
    public let duration: Double // in steps
    
    public init(pitch: UInt32, velocity: UInt32 = 80, channel: UInt32 = 0, duration: Double = 1) {
        self.pitch = pitch
        self.velocity = velocity
        self.channel = channel
        self.duration = duration
    }
}

let midiQueue = DispatchQueue(label: "midi")

public extension MIDINote {
    public func play(onUnit unit: AudioUnit, stepDuration: Double) {
        _ = midiQueue.sync {
            MusicDeviceMIDIEvent(unit, 0x90 | self.channel, self.pitch, self.velocity, 0)
        }
        midiQueue.asyncAfter(deadline: DispatchTime.now()+(self.duration * stepDuration), execute: {
            MusicDeviceMIDIEvent(unit, 0x80 | self.channel, self.pitch, self.velocity, 0)

        })
    }
}

