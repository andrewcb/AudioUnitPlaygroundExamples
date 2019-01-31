import Foundation
import AudioUnit

// --- Something that can evaluate to zero or more MIDI notes

public protocol ProducingMIDINotes {
    var notes: [MIDINote] { get }
}


public protocol SequencerStep {
    var stepDuration: Int { get }
}

public class StepSequencer<S: SequencerStep & ProducingMIDINotes> {
    
    var instrumentUnit: AudioUnit?
    var sequence: [S] {
        didSet {
            self.seqPos = 0
        }
    }
    // the step duration, in seconds
    public var stepDuration: Double
    
    private var seqPos: Int = 0
    
    public var running: Bool = false {
        didSet(previously) {
            if self.running && !previously {
                self.spawnLoop()
            }
        }
    }
    
    public init(stepDuration: Double, instrumentUnit: AudioUnit, sequence: [S]) {
        self.stepDuration = stepDuration
        self.instrumentUnit = instrumentUnit
        self.sequence = sequence
    }
    
    private let seqQueue = DispatchQueue(label: "seq")
    private var stepsUntilNext = 0
    
    private func spawnLoop() {
        self.seqQueue.async {
            while (self.running) {
                guard !self.sequence.isEmpty else {
                    self.running = false
                    break
                }
                let usecPerStep = useconds_t(self.stepDuration * 1_000_000)
                if self.stepsUntilNext > 0 {
                    self.stepsUntilNext -= 1
                } else {
                    if self.seqPos >= self.sequence.endIndex {
                        self.seqPos = self.sequence.startIndex
                    }
                    let event = self.sequence[self.seqPos]
                    self.seqPos = self.sequence.index(after: self.seqPos)
                    self.stepsUntilNext = event.stepDuration - 1
                    
                    if let instrumentUnit = self.instrumentUnit {
                        event.notes.forEach { $0.play(onUnit: instrumentUnit, stepDuration:  self.stepDuration) }
                    }
                }
                usleep(usecPerStep)
            }
        }
        
    }
    
}
