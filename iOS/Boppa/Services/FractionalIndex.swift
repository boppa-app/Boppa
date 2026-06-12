import Foundation

/// Fractional indexing: generates string keys that sort lexicographically and always
/// allow insertion between any two adjacent keys without rewriting neighbors.
/// Based on the algorithm by Evan Wallace / Igor Radzhabov (fractional-indexing JS package).
///
/// Key format: [head][integer digits][optional fractional digits]
///   head 'a' = 1 integer digit, 'b' = 2, ..., 'z' = 26
///   digit set: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" (base62)
///   fractional digits: any digits, trailing '0' is not allowed
enum FractionalIndex {
    private static let base62 = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    private static let base62Count = 62

    private static func digitIndex(_ c: Character) -> Int {
        self.base62.firstIndex(of: c) ?? 0
    }

    /// Total length of the integer part (head + digits) for a given head.
    /// 'a'→2 (1 digit), 'b'→3, ..., 'z'→27
    private static func integerLength(forHead head: Character) -> Int {
        let aVal = Character("a").asciiValue!
        let zVal = Character("z").asciiValue!
        let AVal = Character("A").asciiValue!
        let ZVal = Character("Z").asciiValue!
        let v = head.asciiValue!
        if v >= aVal && v <= zVal { return Int(v - aVal) + 2 }
        if v >= AVal && v <= ZVal { return Int(ZVal - v) + 2 }
        preconditionFailure("Invalid fractional index head: \(head)")
    }

    private static func integerPart(of key: String) -> String {
        guard let head = key.first else { preconditionFailure("Empty fractional index key") }
        let len = self.integerLength(forHead: head)
        precondition(key.count >= len, "Fractional index key too short: \(key)")
        return String(key.prefix(len))
    }

    /// Returns the next integer string, or nil on overflow.
    private static func incrementInteger(_ x: String) -> String? {
        let head = x.first!
        var digs = Array(x.dropFirst())
        for i in stride(from: digs.count - 1, through: 0, by: -1) {
            let d = self.digitIndex(digs[i])
            if d < self.base62Count - 1 {
                digs[i] = self.base62[d + 1]
                return String(head) + String(digs)
            }
            digs[i] = self.base62[0]
        }
        let headVal = head.asciiValue!
        guard headVal < Character("z").asciiValue! else { return nil }
        let newHead = Character(UnicodeScalar(headVal + 1))
        let newDigitCount = self.integerLength(forHead: newHead) - 1
        return String(newHead) + String(repeating: self.base62[0], count: newDigitCount)
    }

    /// Returns the previous integer string, or nil on underflow.
    private static func decrementInteger(_ x: String) -> String? {
        let head = x.first!
        var digs = Array(x.dropFirst())
        for i in stride(from: digs.count - 1, through: 0, by: -1) {
            let d = self.digitIndex(digs[i])
            if d > 0 {
                digs[i] = self.base62[d - 1]
                return String(head) + String(digs)
            }
            digs[i] = self.base62[self.base62Count - 1]
        }
        let headVal = head.asciiValue!
        guard headVal > Character("a").asciiValue! else { return nil }
        let newHead = Character(UnicodeScalar(headVal - 1))
        let newDigitCount = self.integerLength(forHead: newHead) - 1
        return String(newHead) + String(repeating: self.base62[self.base62Count - 1], count: newDigitCount)
    }

    // Lexicographic midpoint between two fractional suffix strings.
    // `a`: lower fractional suffix ("" means no lower bound).
    // `b`: upper fractional suffix, or nil for no upper bound.
    private static func midpoint(_ a: String, _ b: String?) -> String {
        let aChars = Array(a)
        if let b, !b.isEmpty {
            let bChars = Array(b)
            var n = 0
            while n < bChars.count {
                let aChar = n < aChars.count ? aChars[n] : self.base62[0]
                guard aChar == bChars[n] else { break }
                n += 1
            }
            if n > 0 {
                return String(bChars.prefix(n))
                    + self.midpoint(String(aChars.dropFirst(n)), String(bChars.dropFirst(n)))
            }
        }

        let digitA = a.isEmpty ? 0 : self.digitIndex(aChars[0])
        let digitB: Int
        if let b, !b.isEmpty {
            digitB = self.digitIndex(b.first!)
        } else {
            digitB = self.base62Count
        }

        if digitB - digitA > 1 {
            let mid = Int((Double(digitA + digitB) / 2.0).rounded())
            return String(self.base62[mid])
        }

        if let b, b.count > 1 {
            return String(b.first!)
        }

        let firstChar = a.isEmpty ? self.base62[0] : aChars[0]
        let rest = a.isEmpty ? "" : String(aChars.dropFirst())
        return String(firstChar) + self.midpoint(rest, nil)
    }

    /// Generates a key strictly between `a` and `b`.
    /// Pass `nil` for `a` to generate before `b`; `nil` for `b` to generate after `a`; both `nil` for the first key.
    static func generateKeyBetween(_ a: String?, _ b: String?) -> String {
        if let a, let b { precondition(a < b, "FractionalIndex: lower bound must be less than upper bound") }

        guard let a else {
            guard let b else { return "a0" }
            let ib = self.integerPart(of: b)
            let fb = String(b.dropFirst(ib.count))
            if ib == "a0" { return "a" + self.midpoint("", fb) }
            if ib > "a0", let prev = decrementInteger(ib) { return prev }
            preconditionFailure("FractionalIndex: cannot generate key before \(b)")
        }

        guard let b else {
            let ia = self.integerPart(of: a)
            let fa = String(a.dropFirst(ia.count))
            if let inc = incrementInteger(ia) { return inc }
            return ia + self.midpoint(fa, nil)
        }

        let ia = self.integerPart(of: a)
        let fa = String(a.dropFirst(ia.count))
        let ib = self.integerPart(of: b)
        let fb = String(b.dropFirst(ib.count))

        if ia == ib { return ia + self.midpoint(fa, fb) }
        if let inc = incrementInteger(ia), inc < ib { return inc }
        return ia + self.midpoint(fa, nil)
    }

    /// Generates `n` evenly distributed keys strictly between `a` and `b`.
    static func generateNKeysBetween(_ a: String?, _ b: String?, n: Int) -> [String] {
        guard n > 0 else { return [] }
        if n == 1 { return [self.generateKeyBetween(a, b)] }

        if b == nil {
            var c = a
            return (0 ..< n).map { _ in
                let key = self.generateKeyBetween(c, nil)
                c = key
                return key
            }
        }

        if a == nil {
            var c = b
            var result: [String] = []
            for _ in 0 ..< n {
                let key = self.generateKeyBetween(nil, c)
                c = key
                result.insert(key, at: 0)
            }
            return result
        }

        let mid = n / 2
        let c = self.generateKeyBetween(a, b)
        return self.generateNKeysBetween(a, c, n: mid) + [c] + self.generateNKeysBetween(c, b, n: n - 1 - mid)
    }
}
