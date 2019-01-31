//
//  Repeating.swift
//
//  Created by acb on 02/08/2018.
//  Copyright © 2018 acb. All rights reserved.
//

import Foundation

public struct RepeatingSequence<S: Sequence>: Sequence, IteratorProtocol {
    var source: S
    
    var iterator: S.Iterator? = nil
    var repeatCount: Int? = nil // nil = forever
    
    init(source: S, repeatCount: Int? = nil) {
        self.source = source
        self.repeatCount = repeatCount
        self.iterator = nil
    }
    
    mutating public func next() -> S.Element? {
        var r = self.iterator?.next()
        if r == nil && (self.repeatCount ?? 1) > 0 {
            self.repeatCount = self.repeatCount.map { $0 - 1 }
            self.iterator = self.source.makeIterator()
            r = self.iterator?.next()
        }
        return r
    }
}

extension Sequence {
    public func repeating() -> LazySequence<RepeatingSequence<Self>> {
        return RepeatingSequence(source: self, repeatCount: nil).lazy
    }
    public func repeating(_ times: Int) -> LazySequence<RepeatingSequence<Self>> {
        return RepeatingSequence(source: self, repeatCount: times).lazy
    }
}

public func *<S>(lhs: S, rhs: Int) -> RepeatingSequence<S> {
    return RepeatingSequence(source: lhs, repeatCount: rhs)
}
