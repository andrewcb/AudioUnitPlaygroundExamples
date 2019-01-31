import Foundation
import AudioUnit

// --- Something that can evaluate to zero or more MIDI notes

public protocol ProducingMIDINotes {
    var notes: [MIDINote] { get }
}


public protocol SequencerStep {
    var stepDuration: Int { get }
}

public class MultiChannelSequencer<S: SequencerStep & ProducingMIDINotes> {
    
    var unitsAndSequences: [(AudioUnit, [S])] = []
    
//    var instrumentUnits: [AudioUnit]
//    var sequences: [[S]] {
//        didSet {
//            self.seqPos = self.sequences.map { _ in 0 }
//        }
//    }
    // the step duration, in seconds
    public var stepDuration: Double
    
    private var seqPos: [Int] = []
    
    public var running: Bool = false {
        didSet(previously) {
            if self.running && !previously {
                self.spawnLoop()
            }
        }
    }
    
    public init(stepDuration: Double, instrumentUnits: [AudioUnit], sequences: [[S]]) {
        self.stepDuration = stepDuration
//        self.instrumentUnits = instrumentUnits
//        self.sequences = sequences
        self.unitsAndSequences = zip(instrumentUnits, sequences).map { $0 }
        self.seqPos = instrumentUnits.map { _ in 0 }
        self.stepsUntilNext = instrumentUnits.map { _ in 0 }
    }
    
    private let seqQueue = DispatchQueue(label: "seq")
    private var stepsUntilNext: [Int] = []
    
    private func spawnLoop() {
        self.seqQueue.async {
            while (self.running) {
                let usecPerStep = useconds_t(self.stepDuration * 1_000_000)

                for (index, (unit, seq)) in self.unitsAndSequences.enumerated() {
                    guard !seq.isEmpty else { continue }
                    
                    if self.stepsUntilNext[index] > 0 {
                        self.stepsUntilNext[index] -= 1
                    } else {
                        if self.seqPos[index] >= seq.endIndex {
                            self.seqPos[index] = seq.startIndex
                        }
                        let event = seq[self.seqPos[index]]
                        self.seqPos[index] = seq.index(after: self.seqPos[index])
                        self.stepsUntilNext[index] = event.stepDuration - 1
                        
                        event.notes.forEach { $0.play(onUnit: unit, stepDuration:  self.stepDuration) }
                        
                    }
                    
                }
                
//                guard !self.sequence.isEmpty else {
//                    self.running = false
//                    break
//                }
//                if self.stepsUntilNext > 0 {
//                    self.stepsUntilNext -= 1
//                } else {
//                    if self.seqPos >= self.sequence.endIndex {
//                        self.seqPos = self.sequence.startIndex
//                    }
//                    let event = self.sequence[self.seqPos]
//                    self.seqPos = self.sequence.index(after: self.seqPos)
//                    self.stepsUntilNext = event.stepDuration - 1
//                    
//                    if let instrumentUnit = self.instrumentUnit {
//                        event.notes.forEach { $0.play(onUnit: instrumentUnit, stepDuration:  self.stepDuration) }
//                    }
//                }
                usleep(usecPerStep)
            }
        }
        
    }
    
}
