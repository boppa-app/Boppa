@testable import Boppa
import Testing

struct FractionalIndexTests {
    // MARK: - generateKeyBetween

    @Test func firstKeyWithNoBoundsIsA0() {
        #expect(FractionalIndex.generateKeyBetween(nil, nil) == "a0")
    }

    @Test func keyAfterAWithNoUpperBoundSortsAfterA() {
        let key = FractionalIndex.generateKeyBetween("a0", nil)
        #expect(key > "a0")
    }

    @Test func keyBeforeBWithNoLowerBoundSortsBeforeB() {
        let key = FractionalIndex.generateKeyBetween(nil, "a0")
        #expect(key < "a0")
    }

    @Test func keyBeforeAnArbitraryKeyStillSortsBeforeIt() {
        let existing = FractionalIndex.generateKeyBetween("a0", nil)
        let key = FractionalIndex.generateKeyBetween(nil, existing)
        #expect(key < existing)
    }

    @Test func repeatedlyMovingToFrontKeepsProducingSmallerKeys() {
        var current = "a0"
        for _ in 0 ..< 20 {
            let next = FractionalIndex.generateKeyBetween(nil, current)
            #expect(next < current)
            current = next
        }
    }

    @Test func keyBetweenTwoBoundsSortsStrictlyBetweenThem() {
        let a = "a0"
        let b = FractionalIndex.generateKeyBetween("a0", nil)
        let mid = FractionalIndex.generateKeyBetween(a, b)
        #expect(mid > a)
        #expect(mid < b)
    }

    @Test func repeatedInsertionsBetweenTheSameBoundsStayOrdered() {
        let a = "a0"
        let b = FractionalIndex.generateKeyBetween("a0", nil)
        var lower = a
        var upper = b
        for _ in 0 ..< 20 {
            let mid = FractionalIndex.generateKeyBetween(lower, upper)
            #expect(mid > lower)
            #expect(mid < upper)
            upper = mid
        }
    }

    // MARK: - generateNKeysBetween

    @Test func nKeysWithNoBoundsAreStrictlyIncreasing() {
        let keys = FractionalIndex.generateNKeysBetween(nil, nil, n: 5)
        #expect(keys == keys.sorted())
        #expect(Set(keys).count == keys.count)
    }

    @Test func nKeysBeforeAnExistingKeyAreStrictlyIncreasingAndAllSortBeforeIt() {
        let bound = "a0"
        let keys = FractionalIndex.generateNKeysBetween(nil, bound, n: 5)
        #expect(keys == keys.sorted())
        #expect(Set(keys).count == keys.count)
        #expect(keys.allSatisfy { $0 < bound })
    }

    @Test func nKeysBetweenTwoBoundsAreStrictlyIncreasingAndWithinBounds() {
        let lower = "a0"
        let upper = FractionalIndex.generateKeyBetween("a0", nil)
        let keys = FractionalIndex.generateNKeysBetween(lower, upper, n: 5)
        #expect(keys == keys.sorted())
        #expect(Set(keys).count == keys.count)
        #expect(keys.allSatisfy { $0 > lower && $0 < upper })
    }
}
