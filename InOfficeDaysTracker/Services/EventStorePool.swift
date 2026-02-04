//
//  EventStorePool.swift
//  InOfficeDaysTracker
//
//  EventStore pooling and memory management for performance optimization
//

import Foundation
import EventKit

/// EventStore pool manager for efficient resource management
class EventStorePool: ObservableObject {
    static let shared = EventStorePool()
    
    private var pooledStores: [PooledEventStore] = []
    private let maxPoolSize: Int = 3
    private let storeLifetime: TimeInterval = 300 // 5 minutes
    private var cleanupTimer: Timer?
    
    /// Represents a pooled EventStore with lifecycle metadata
    private class PooledEventStore {
        let eventStore: EKEventStore
        let createdAt: Date
        var lastUsed: Date
        var usageCount: Int = 0
        
        init() {
            self.eventStore = EKEventStore()
            self.createdAt = Date()
            self.lastUsed = Date()
        }
        
        func markUsed() {
            lastUsed = Date()
            usageCount += 1
        }
        
        var isExpired: Bool {
            Date().timeIntervalSince(lastUsed) > 300 // storeLifetime constant
        }
        
        var age: TimeInterval {
            Date().timeIntervalSince(createdAt)
        }
    }
    
    private init() {
        setupCleanupTimer()
        debugLog("🏊", "[EventStorePool] Initialized with max pool size: \(maxPoolSize)")
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    /// Get an EventStore from the pool or create a new one
    func borrowEventStore() -> EKEventStore {
        // Try to reuse an existing store
        if let pooledStore = pooledStores.first(where: { !$0.isExpired }) {
            pooledStore.markUsed()
            let formattedAge = String(format: "%.1f", pooledStore.age)
            debugLog("🏊", "[EventStorePool] Reusing EventStore (age: \(formattedAge)s, usage: \(pooledStore.usageCount))")
            return pooledStore.eventStore
        }
        
        // Create new store if pool isn't full
        if pooledStores.count < maxPoolSize {
            let newStore = PooledEventStore()
            pooledStores.append(newStore)
            newStore.markUsed()
            debugLog("🏊", "[EventStorePool] Created new EventStore (pool size: \(pooledStores.count)/\(maxPoolSize))")
            return newStore.eventStore
        }
        
        // Pool is full, replace oldest expired store or reuse least recently used
        if let expiredStore = pooledStores.first(where: { $0.isExpired }) {
            if let index = pooledStores.firstIndex(where: { $0 === expiredStore }) {
                pooledStores.remove(at: index)
            }
            
            let newStore = PooledEventStore()
            pooledStores.append(newStore)
            newStore.markUsed()
            debugLog("🏊", "[EventStorePool] Replaced expired EventStore")
            return newStore.eventStore
        }
        
        // No expired stores, use least recently used
        let leastUsed = pooledStores.min { $0.lastUsed < $1.lastUsed }!
        leastUsed.markUsed()
        debugLog("🏊", "[EventStorePool] Reusing least recently used EventStore")
        return leastUsed.eventStore
    }
    
    /// Return an EventStore to the pool (no-op for compatibility, stores remain pooled)
    func returnEventStore(_ eventStore: EKEventStore) {
        // Find the pooled store and update usage
        if let pooledStore = pooledStores.first(where: { $0.eventStore === eventStore }) {
            pooledStore.markUsed()
        }
    }
    
    /// Force cleanup of expired stores
    func cleanupExpiredStores() {
        let initialCount = pooledStores.count
        pooledStores.removeAll { $0.isExpired }
        let removedCount = initialCount - pooledStores.count
        
        if removedCount > 0 {
            debugLog("🏊", "[EventStorePool] Cleaned up \(removedCount) expired EventStores (remaining: \(pooledStores.count))")
        }
    }
    
    /// Get pool statistics for monitoring
    var poolStatistics: PoolStatistics {
        let totalUsage = pooledStores.reduce(0) { $0 + $1.usageCount }
        let avgAge = pooledStores.isEmpty ? 0 : pooledStores.map { $0.age }.reduce(0, +) / Double(pooledStores.count)
        
        return PoolStatistics(
            poolSize: pooledStores.count,
            maxPoolSize: maxPoolSize,
            totalUsage: totalUsage,
            averageAge: avgAge,
            expiredCount: pooledStores.filter { $0.isExpired }.count
        )
    }
    
    /// Clear all pooled stores (useful for memory pressure situations)
    func clearPool() {
        let clearedCount = pooledStores.count
        pooledStores.removeAll()
        debugLog("🏊", "[EventStorePool] Cleared all EventStores (cleared: \(clearedCount))")
    }
    
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.cleanupExpiredStores()
        }
    }
}

/// Statistics about the EventStore pool
struct PoolStatistics {
    let poolSize: Int
    let maxPoolSize: Int
    let totalUsage: Int
    let averageAge: TimeInterval
    let expiredCount: Int
    
    var utilizationPercentage: Double {
        guard maxPoolSize > 0 else { return 0 }
        return Double(poolSize) / Double(maxPoolSize) * 100
    }
}

/// Memory management extensions for EventStore operations
extension EventStorePool {
    /// Handle memory pressure by clearing old stores
    func handleMemoryPressure() {
        debugLog("⚠️", "[EventStorePool] Handling memory pressure - clearing expired stores")
        
        // First, remove expired stores
        cleanupExpiredStores()
        
        // If still over capacity, remove older stores
        if pooledStores.count > maxPoolSize / 2 {
            let keepCount = maxPoolSize / 2
            pooledStores.sort { $0.lastUsed > $1.lastUsed } // Keep most recently used
            let removedCount = pooledStores.count - keepCount
            pooledStores = Array(pooledStores.prefix(keepCount))
            debugLog("⚠️", "[EventStorePool] Removed \(removedCount) stores due to memory pressure")
        }
    }
    
    /// Get memory footprint estimation
    var estimatedMemoryUsage: Int {
        // Rough estimate: each EventStore ~500KB + metadata
        return pooledStores.count * 512 * 1024
    }
}

/// Performance monitoring for EventStore operations
class EventStorePerformanceMonitor {
    static let shared = EventStorePerformanceMonitor()
    
    private var operationTimes: [String: [TimeInterval]] = [:]
    private let maxRecordedTimes = 50
    
    private init() {}
    
    /// Measure operation performance
    func measureOperation<T>(_ operationName: String, operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        recordOperationTime(operationName, duration: duration)
        
        if duration > 1.0 { // Log slow operations
            let formattedDuration = String(format: "%.3f", duration)
            debugLog("⏱️", "[Performance] Slow operation '\(operationName)': \(formattedDuration)s")
        }
        
        return result
    }
    
    /// Measure async operation performance
    func measureAsyncOperation<T>(_ operationName: String, operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        recordOperationTime(operationName, duration: duration)
        
        if duration > 1.0 { // Log slow operations
            let formattedDuration = String(format: "%.3f", duration)
            debugLog("⏱️", "[Performance] Slow async operation '\(operationName)': \(formattedDuration)s")
        }
        
        return result
    }
    
    private func recordOperationTime(_ operationName: String, duration: TimeInterval) {
        if operationTimes[operationName] == nil {
            operationTimes[operationName] = []
        }
        
        operationTimes[operationName]?.append(duration)
        
        // Keep only recent measurements
        if let count = operationTimes[operationName]?.count, count > maxRecordedTimes {
            operationTimes[operationName]?.removeFirst()
        }
    }
    
    /// Get performance statistics for an operation
    func getStatistics(for operationName: String) -> OperationStatistics? {
        guard let times = operationTimes[operationName], !times.isEmpty else { return nil }
        
        let average = times.reduce(0, +) / Double(times.count)
        let min = times.min() ?? 0
        let max = times.max() ?? 0
        
        return OperationStatistics(
            operationName: operationName,
            sampleCount: times.count,
            averageDuration: average,
            minDuration: min,
            maxDuration: max
        )
    }
    
    /// Get all recorded performance statistics
    var allStatistics: [OperationStatistics] {
        return operationTimes.compactMap { getStatistics(for: $0.key) }
    }
}

struct OperationStatistics {
    let operationName: String
    let sampleCount: Int
    let averageDuration: TimeInterval
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    
    var formattedAverage: String {
        String(format: "%.3f", averageDuration)
    }
}