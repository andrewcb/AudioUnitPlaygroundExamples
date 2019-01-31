import Foundation
import AudioToolbox
import CoreAudio
import AudioUnit

/// utility code for constructing and manipulating the AudioUnit graph

//  Make a NSError from a nonzero OSStatus
extension NSError {
    convenience init(osstatus: OSStatus) {
        self.init(domain: NSOSStatusErrorDomain, code: Int(osstatus), userInfo: nil)
    }
}

func osStatusCheck(_ status: OSStatus) throws {
    if status != 0 {
        throw NSError(osstatus: status)
    }
}

// minimal modern Swift wrappings of the AudioUnit/Graph functions

public struct Graph {
    let auRef: AUGraph
    
    public init() throws {
        var result: AUGraph? = nil
        try osStatusCheck(NewAUGraph(&result))
        self.auRef = result!
    }
    
    public func open() throws { try osStatusCheck(AUGraphOpen(auRef)) }
    public func close() throws { try osStatusCheck(AUGraphClose(auRef)) }
    public func initialize() throws { try osStatusCheck(AUGraphInitialize(auRef)) }
    public func uninitialize() throws { try osStatusCheck(AUGraphUninitialize(auRef)) }
    public func start() throws { try osStatusCheck(AUGraphStart(auRef)) }
    public func stop() throws { try osStatusCheck(AUGraphStop(auRef)) }
    
    public func addNode(fromDescription desc: AudioComponentDescription) throws -> AUNode {
        // we must copy this to a var, because AUv2 functions want a pointer to it
        var desc = desc
        var result: AUNode = 0
        try osStatusCheck(AUGraphAddNode(self.auRef, &desc, &result))
        return result
    }
    
    public func getAudioUnit(fromNode node: AUNode) throws -> AudioUnit {
        var result: AudioUnit?
        try osStatusCheck(AUGraphNodeInfo(auRef, node, nil, &result))
        return result!
    }
    
    public func connect(node srcNode: AUNode, output srcOut: UInt32 = 0, toNode destNode: AUNode, input destIn: UInt32 = 0 ) throws {
        try osStatusCheck(AUGraphConnectNodeInput(auRef, srcNode, srcOut, destNode, destIn))
    }
}


/// The descriptions of the components we need: the output and the built-in General MIDI synth

public extension AudioComponentDescription {
    
    public init(type: OSType, subType: OSType, manufacturer: OSType) {
        self.init(componentType: type, componentSubType: subType, componentManufacturer: manufacturer, componentFlags: 0, componentFlagsMask: 0)
    }
    
    public static let defaultOutput = AudioComponentDescription(type: kAudioUnitType_Output, subType: kAudioUnitSubType_DefaultOutput, manufacturer: kAudioUnitManufacturer_Apple)
    public static let stereoMixer = AudioComponentDescription(
        type: kAudioUnitType_Mixer,
        subType: kAudioUnitSubType_StereoMixer,
        manufacturer: kAudioUnitManufacturer_Apple)
    public static let multiChannelMixer = AudioComponentDescription(
        type: kAudioUnitType_Mixer,
        subType: kAudioUnitSubType_MultiChannelMixer,
        manufacturer: kAudioUnitManufacturer_Apple)
    public static let dlsSynth = AudioComponentDescription(
        type: kAudioUnitType_MusicDevice,
        subType: kAudioUnitSubType_DLSSynth,
        manufacturer: kAudioUnitManufacturer_Apple)
}

