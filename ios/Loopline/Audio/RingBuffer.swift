import Foundation
import os

/// A lock-guarded single-producer / single-consumer float ring buffer used to
/// hand PCM from the network thread to the audio render thread.
final class FloatRingBuffer {
    private var storage: [Float]
    private let capacity: Int
    private var head = 0   // read index
    private var tail = 0   // write index
    private var count = 0
    private var lock = os_unfair_lock_s()

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = [Float](repeating: 0, count: capacity)
    }

    var available: Int {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return count
    }

    /// Write samples, dropping the oldest if the buffer would overflow.
    func write(_ samples: UnsafeBufferPointer<Float>) {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        for s in samples {
            storage[tail] = s
            tail = (tail + 1) % capacity
            if count == capacity {
                head = (head + 1) % capacity  // overwrite oldest
            } else {
                count += 1
            }
        }
    }

    /// Read up to `dst.count` samples, zero-filling any underrun. Returns count read.
    @discardableResult
    func read(into dst: UnsafeMutableBufferPointer<Float>) -> Int {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        let n = min(dst.count, count)
        for i in 0 ..< n {
            dst[i] = storage[head]
            head = (head + 1) % capacity
        }
        for i in n ..< dst.count { dst[i] = 0 }  // underrun → silence
        count -= n
        return n
    }

    func clear() {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        head = 0; tail = 0; count = 0
    }

    /// Discard the oldest `n` samples (used to bound playback latency).
    func drop(_ n: Int) {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        let d = min(n, count)
        head = (head + d) % capacity
        count -= d
    }
}
