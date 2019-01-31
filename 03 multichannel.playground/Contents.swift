/*
 *  Example 3: play a piece on several channels, with different instruments
 */

import Foundation
import AudioToolbox
import CoreAudio
import AudioUnit
import PlaygroundSupport

// --------------------------------------------------------------

// A helpful structure representing an AUNode which may be loaded from a preset (assuming that the plugin for the preset is available) or, if not, fall back to a General MIDI patch using DLSSynth.

struct PluginWithFallback {
    private let graph: Graph
    private let preset: AudioUnitPreset
    var node: AUNode
    let unit: AudioUnit
    private let fallbackGMProgram: UInt32
    private let isUsingPreset: Bool
    
    init(graph: Graph, presetResource: String, fallingBackTo program: UInt32) throws {
        self.graph = graph
        self.preset = try AudioUnitPreset.fromResource(named: presetResource)
        self.fallbackGMProgram = program
        do {
            self.node = try graph.addNode(fromDescription: self.preset.audioComponentDescription)
            self.unit = try graph.getAudioUnit(fromNode: self.node)
            self.isUsingPreset = true
        } catch {
            self.node = try graph.addNode(fromDescription: .dlsSynth)
            self.unit = try graph.getAudioUnit(fromNode: self.node)
            self.isUsingPreset = false
        }
    }
    
    // prepare the AudioUnit by setting its program appropriately
    func configureAudioUnit() throws  {
        if self.isUsingPreset {
            try self.preset.load(into: self.unit)
        } else {
            MusicDeviceMIDIEvent(self.unit, 0xc0, self.fallbackGMProgram, 0, 0)
        }
    }
}


// Create the graph
let graph = try Graph()

//MARK: load the AudioUnits

// Create the two nodes
let outNode = try graph.addNode(fromDescription: .defaultOutput)
let mixerNode = try graph.addNode(fromDescription: .stereoMixer)

try graph.open()

// track 1: the synth pad (Roland Cloud JV-1080; falling back to GM Warm Pad)
let pad = try PluginWithFallback(graph: graph, presetResource: "Dreamesque", fallingBackTo: 90)

// track 2: a synth bass (NI FM8; falling back to GM Synth Bass)
let bass = try PluginWithFallback(graph: graph, presetResource: "FM8 Dancy Pluck Syn", fallingBackTo: 39)

// track  3: piano (Korg M1; falling back to GM Electric Grand)
let piano = try PluginWithFallback(graph: graph, presetResource: "M1HousePiano", fallingBackTo: 3)

// track 4: pluck (NI Massive; falling back to GM Ice Rain)
let pluck = try PluginWithFallback(graph: graph, presetResource: "MSV Harpolodic", fallingBackTo: 97)

try graph.initialize()

/// Get the AudioUnit instances for the instruments
let mixerUnit = try graph.getAudioUnit(fromNode: mixerNode)


try graph.connect(node: pad.node, toNode: mixerNode, input: 0)
try graph.connect(node: bass.node, toNode: mixerNode, input: 1)
try graph.connect(node: piano.node, toNode: mixerNode, input: 2)
try graph.connect(node: pluck.node, toNode: mixerNode, input: 3)
try graph.connect(node: mixerNode, toNode: outNode)

try graph.start()

/// set up instruments

try pad.configureAudioUnit()
try bass.configureAudioUnit()
try piano.configureAudioUnit()
try pluck.configureAudioUnit()

usleep(500000)

// -----
// Some definitions for playing MIDI notes

let tempo = 120.0 // BPM
let stepsPerBeat = 4

let stepDuration = (60.0/(tempo*Double(stepsPerBeat)))



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

// --- Sequencer steps; these work with our custom StepSequencer<S> class.
// SeqItem works in scale degrees, rather than MIDI note values, which keeps things a bit simpler.

struct SeqItem: SequencerStep {
    let scaleDegrees: [Int]
    let stepDuration: Int
    let legato: Double
}

extension SeqItem: ProducingMIDINotes {
    var notes: [MIDINote] {
        return self.scaleDegrees.map { (deg) in
            MIDINote(pitch: note(deg, ofScale: scale), velocity: 80, channel: 0, duration: Double(self.stepDuration)*self.legato)
        }
    }
}

func rest(forBeats beats: Int) -> [SeqItem] {
    return [SeqItem(scaleDegrees: [], stepDuration: beats*stepsPerBeat, legato: 0.8) ]
}

// make some chords
let padProg = [(0,2), (4,1), (3,1)]
let padSeq: [SeqItem] =  (padProg.map { (deg, dur) in SeqItem(scaleDegrees: [deg+7, deg+9, deg+11 ], stepDuration: 16*dur, legato: 0.8 ) })

// an arpeggio line
let arpSeq: [SeqItem] = (([0, 0, 4, 3]).flatMap { (offset) in
    [2, 0, 3, 1, 2, 0, 3, 1].map { (deg) in
        SeqItem(scaleDegrees: [offset+deg], stepDuration: 1, legato: 0.75)
    }
})

// and a bassline
let bassSeq1 = rest(forBeats: 64)
let bassSeq2 = (([0, 0, 4, 3].repeating(8)).flatMap { (offset) in
    [(0, 2), (1, 2), (1, 1), (0, 2), (1, 1)].map { (oct, dur) in
        SeqItem(scaleDegrees: [(oct-1)*7 + offset], stepDuration: dur, legato: 0.8)
    }
})
let bassSeq3 = (([0, 0, 4, 3].repeating(2)).flatMap { (offset) in
        [(0, 2), (1, 5), (1, 1)].map { (oct, dur) in
            SeqItem(scaleDegrees: [(oct-1)*7 + offset], stepDuration: dur, legato: 0.8)
        }
    })

let bassSeq = bassSeq1 + bassSeq2 + bassSeq3

/// cheesy house piano c. 1990

/// This is split up because the Swift interpreter gives up on typechecking it otherwise
let pianoSeq1 = rest(forBeats: 96)
    
let pianoSeq2 = ((([0, 0, 2, -2].repeating(1)).flatMap { (offset) in [
    ([2,4,6], 2), ([], 1), ([2,4,6], 2), ([0], 1),
    ([2,4,6], 2), ([], 1), ([2,4,6], 2), ([], 1),
    ([2,4,6], 1), ([0], 1), ([2,4,6], 1), ([], 1),
    ([], 4), ([], 12)
    ].map { (a, b) in (a.map { $0 + offset}, b) }}
    ).map { (degs, dur) in
        SeqItem(scaleDegrees: degs, stepDuration: dur, legato: 0.8)
    })

let pianoSeq = pianoSeq1 + pianoSeq2

let pluckSeq =  rest(forBeats: 144) + (([0, 2, 5, 4].repeating(2)).flatMap { (offset) in  (([0, 2, 4, 8, 7, 5, 3, 1].repeating(1)).map { SeqItem(scaleDegrees:[offset+$0], stepDuration: 1, legato: 0.8)  }) })

let seq = MultiChannelSequencer(
    stepDuration: stepDuration,
    instrumentUnits: [pad.unit,  bass.unit, piano.unit, pluck.unit],
    sequences: [padSeq, bassSeq, pianoSeq, pluckSeq])
seq.running = true


PlaygroundPage.current.needsIndefiniteExecution = true

