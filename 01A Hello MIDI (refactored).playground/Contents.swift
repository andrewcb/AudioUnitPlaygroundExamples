/*
 *  Example 1: create one instrument and an output and play a few notes (after refactoring)
 */

import Foundation
import AudioToolbox
import CoreAudio
import AudioUnit


// --------------------------------------------------------------

// Create the graph
let graph = try Graph()

// Create the two nodes
let outNode = try graph.addNode(fromDescription: .defaultOutput)
let instrumentNode = try graph.addNode(fromDescription: .dlsSynth)

try graph.open()

/// Get the AudioUnit instance for the instrument
let instrumentUnit = try graph.getAudioUnit(fromNode: instrumentNode)

try graph.initialize()

try graph.connect(node: instrumentNode, toNode: outNode)

try graph.start()

let majorScale = [ 0, 2, 4, 5, 7, 9, 11 ]

for degree in majorScale {
    MusicDeviceMIDIEvent(instrumentUnit, 0x90, UInt32(60+degree), 80, 0)
    usleep(500000)
    MusicDeviceMIDIEvent(instrumentUnit, 0x80, UInt32(60+degree), 80, 0)
}


