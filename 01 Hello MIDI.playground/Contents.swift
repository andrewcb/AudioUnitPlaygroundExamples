/*
 *  Example 1: create one instrument and an output and play a few notes
 */

import Foundation
import AudioToolbox
import CoreAudio
import AudioUnit

/// The descriptions of the components we need: the output and the built-in General MIDI synth
var defaultOutput = AudioComponentDescription(
    componentType:  kAudioUnitType_Output,
    componentSubType: kAudioUnitSubType_DefaultOutput,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0, componentFlagsMask: 0)

var instrumentSpec = AudioComponentDescription(
    componentType: kAudioUnitType_MusicDevice,
    componentSubType: kAudioUnitSubType_DLSSynth,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0, componentFlagsMask: 0)


// Create the graph
var graph: AUGraph? = nil
if NewAUGraph(&graph) != 0 { fatalError("Graph creation failed") }

// Create the two nodes
var outNode: AUNode = 0
var instrumentNode: AUNode = 0
AUGraphAddNode(graph!, &defaultOutput, &outNode)
AUGraphAddNode(graph!, &instrumentSpec, &instrumentNode)

AUGraphOpen(graph!)

/// Get the AudioUnit instance for the instrument
var instrumentUnit: AudioUnit?
AUGraphNodeInfo(graph!, instrumentNode, nil, &instrumentUnit)

AUGraphInitialize(graph!)

AUGraphConnectNodeInput(graph!, instrumentNode, 0, outNode, 0)
AUGraphStart(graph!)

let majorScale = [ 0, 2, 4, 5, 7, 9, 11 ]

for degree in majorScale {
    MusicDeviceMIDIEvent(instrumentUnit!, 0x90, UInt32(60+degree), 80, 0)
    usleep(500000)
    MusicDeviceMIDIEvent(instrumentUnit!, 0x80, UInt32(60+degree), 80, 0)
}


