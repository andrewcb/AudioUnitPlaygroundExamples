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
    public static let midiSynth = AudioComponentDescription(
        type: kAudioUnitType_MusicDevice,
        subType: kAudioUnitSubType_MIDISynth,
        manufacturer: kAudioUnitManufacturer_Apple)
}

/// An AudioUnitPreset, which encapsulates a .aupreset object, and the code for reading (and writing) it
public struct AudioUnitPreset {
    
    public let propertyList: [String:Any]
    
    public enum Error: Swift.Error {
        case malformedData(String)
        case badName
    }
    
    // convenience function for constructing from a resource in a bundle
    
    public static func fromResource(named name: String, inBundle bundle: Bundle = .main) throws -> AudioUnitPreset {
        guard let url = bundle.url(forResource: name, withExtension: "aupreset") else { throw Error.badName }
        return try AudioUnitPreset(url: url)
    }
    
    // initialise it from a .aupreset file
    public init(path: String) throws {
        try self.init(url: URL(fileURLWithPath: path))
    }
    public init(url: URL) throws {
        let data = try Data(contentsOf: url)
        try self.init(data: data)
    }
    
    public init(data: Data) throws {
        guard let pl = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String:Any] else { throw Error.malformedData("Not a property list") }
        try self.init(propertyList: pl)
    }
    
    public init(propertyList pl: [String:Any]) throws {
        guard
            pl["type"] as? OSType != nil,
            pl["subtype"] as? OSType != nil,
            pl["manufacturer"] as? OSType != nil
            else { throw Error.malformedData("One or more of (type, subtype, manufacturer) is missing") }
        
        self.propertyList = pl
    }
    
    // synthesise a bare-bones AudioUnitPreset from an AudioComponentDescription; this will not actually do anything more than load the component and leave it in its default state, though it is guaranteed to produce a valid AudioUnitPreset for any AudioComponentDescription; it may be used if a unit, for some reason, will not return a valid ClassInfo
    public static func makeWithComponentOnly(from desc: AudioComponentDescription) -> AudioUnitPreset {
        return try! AudioUnitPreset(propertyList: [
            "type" : desc.componentType,
            "subtype": desc.componentSubType,
            "manufacturer": desc.componentManufacturer
            ])
    }
    
    var type: OSType { return self.propertyList["type"] as! OSType }
    var subtype: OSType { return self.propertyList["subtype"] as! OSType }
    var manufacturer: OSType { return self.propertyList["manufacturer"] as! OSType }
    public var audioComponentDescription: AudioComponentDescription {
        return AudioComponentDescription(
            componentType: self.type,
            componentSubType: self.subtype,
            componentManufacturer: self.manufacturer,
            componentFlags: 0, componentFlagsMask: 0)
    }
    
    public func asData() throws -> Data {
        return try PropertyListSerialization.data(fromPropertyList: self.propertyList, format: PropertyListSerialization.PropertyListFormat.xml, options: 0)
    }
    
    
    // Load this preset's data into an initialised AudioUnit
    public func load(into unit: AudioUnit) throws {
        var classInfo = self.propertyList as NSDictionary as CFDictionary        
        try osStatusCheck(AudioUnitSetProperty(unit, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &classInfo, UInt32(MemoryLayout<CFDictionary>.size)))
    }
}
