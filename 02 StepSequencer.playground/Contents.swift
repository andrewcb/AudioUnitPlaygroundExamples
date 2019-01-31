/*
 *  Example 2: play a repeating sequence of notes, on several possible instruments
 */

import Foundation
import AudioToolbox
import CoreAudio
import AudioUnit
import PlaygroundSupport

// --------------------------------------------------------------


// Create the graph
let graph = try Graph()

// Create the two nodes
let outNode = try graph.addNode(fromDescription: .defaultOutput)

// Load an instrument node; here, we have several options:

enum InstrumentOption {
    case builtInGeneralMidi
    case soundFont
    case softSynthFromDescription
    case audioUnitPreset
}

//let instrumentOption = InstrumentOption.builtInGeneralMidi
let instrumentOption = InstrumentOption.audioUnitPreset

var instrumentNode: AUNode = 0

var preset: AudioUnitPreset? = nil

switch(instrumentOption) {
    
// Option 1: DLSSynth, the built-in General MIDI sound set.
case .builtInGeneralMidi:
    instrumentNode = try graph.addNode(fromDescription: .dlsSynth)
    
// Option 2: load a SoundFont (in this case, packaged into this Playground's resources directory)
case .soundFont:
    instrumentNode = try graph.addNode(fromDescription: .midiSynth)
    // Once initialised, make sure to load the SoundFont
    
// Option 3A: Load a softsynth (in this case, Native Instruments Massive) by description; it will be running its default preset
case .softSynthFromDescription:
    let desc_Massive = AudioComponentDescription(
        type: kAudioUnitType_MusicDevice,
        subType: 0x4e694d61,     // 'NiMa'
        manufacturer: 0x2d4e492d // '-NI-'
    )
    instrumentNode = try graph.addNode(fromDescription: desc_Massive)

// Option 3B: Load a softsynth from a .aupreset file
case .audioUnitPreset:
    preset = try AudioUnitPreset.fromResource(named: "BAS Massive PistonStroke")
    // step 1: load the plugin the preset  is for
    instrumentNode = try graph.addNode(fromDescription: preset!.audioComponentDescription)
    // Once initialised, we need to set the instrument's preset from data
}








try graph.open()

/// Get the AudioUnit instance for the instrument
let instrumentUnit = try graph.getAudioUnit(fromNode: instrumentNode)

try graph.initialize()

try graph.connect(node: instrumentNode, toNode: outNode)

try graph.start()


switch(instrumentOption) {
    
case .builtInGeneralMidi:
    // Program change: select a different General MIDI instrument
//    MusicDeviceMIDIEvent(instrumentUnit, 0xc0, 33, 0, 0)
    break
    
case .soundFont:
    var url = Bundle.main.url(forResource: "SynthBass2", withExtension: "sf2")!
    AudioUnitSetProperty(instrumentUnit, kMusicDeviceProperty_SoundBankURL, kAudioUnitScope_Global, 0, &url, UInt32(MemoryLayout<URL>.size))
    
case .audioUnitPreset:
    try preset!.load(into: instrumentUnit)
    
default:
    break
}


usleep(500000)

// -----
// Some definitions for playing MIDI notes

let tempo = 120.0 // BPM
let stepsPerBeat = 4

let stepDuration = (60.0/(tempo*Double(stepsPerBeat)))



// --- a sequencer

let majorScale = [ 0, 2, 4, 5, 7, 9, 11 ]
let minorScale = [ 0, 2, 3, 5, 7, 8, 10 ]
let scale = majorScale

// get a degree of a scale, wrapping around if need be
func note(_ degree: Int, ofScale scale: [Int], basedAt zeroPoint: UInt32 = 60) -> UInt32 {
    let scaleSize = scale.count
    if degree < 0 {
        let mdeg = ((degree % scaleSize) + scaleSize ) % scaleSize
        let off = (degree - (scaleSize - 1)) / scaleSize
        return UInt32(Int(zeroPoint) + (off * 12) + scale[mdeg])
    } else {
        return UInt32(Int(zeroPoint) + scale[degree % scaleSize] + 12 * (degree / scaleSize))
    }
}



struct SeqItem: SequencerStep {
    // nil = a rest
    let scaleDegree: Int?
    let stepDuration: Int
}

extension SeqItem: ProducingMIDINotes {
    var notes: [MIDINote] {
        guard let deg = self.scaleDegree else { return [] }
        return [MIDINote(pitch: note(deg, ofScale: scale), velocity: 80, channel: 0, duration: Double(self.stepDuration))]
    }
}


let sequence = [
    SeqItem(scaleDegree: -7, stepDuration: 2),
    SeqItem(scaleDegree: 0, stepDuration: 2),
    SeqItem(scaleDegree: 0, stepDuration: 2),
    SeqItem(scaleDegree: -7, stepDuration: 2),
    SeqItem(scaleDegree: 0, stepDuration: 1),
    SeqItem(scaleDegree: -7, stepDuration: 2),
    SeqItem(scaleDegree: -7, stepDuration: 2),
    SeqItem(scaleDegree: 0, stepDuration: 2),
    SeqItem(scaleDegree: 0, stepDuration: 1)
]
let seq = StepSequencer<SeqItem>(stepDuration: stepDuration, instrumentUnit: instrumentUnit, sequence: sequence)
seq.running = true


PlaygroundPage.current.needsIndefiniteExecution = true

