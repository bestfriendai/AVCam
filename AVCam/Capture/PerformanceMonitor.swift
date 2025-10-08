/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Performance monitoring for capture quality and system resources.
*/

import AVFoundation
import Combine
import os.log

/// Performance monitoring for capture quality and system resources.
final class PerformanceMonitor: ObservableObject {
    
    private let logger = Logger(subsystem: "com.apple.AVCam", category: "PerformanceMonitor")
    
    @Published private(set) var currentMetrics: PerformanceMetrics = .unknown
    
    private var monitoringTimer: Timer?
    private let updateInterval: TimeInterval = 1.0
    
    func startMonitoring() {
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func updateMetrics() {
        let metrics = PerformanceMetrics(
            frameRate: getCurrentFrameRate(),
            cpuUsage: getCurrentCPUUsage(),
            memoryUsage: getCurrentMemoryUsage(),
            thermalState: ProcessInfo.processInfo.thermalState,
            batteryLevel: getCurrentBatteryLevel(),
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.currentMetrics = metrics
        }
        
        // Log warnings for performance issues
        logPerformanceWarnings(metrics)
    }
    
    private func getCurrentFrameRate() -> Double {
        // Implementation would track actual frame rate from capture outputs
        return 30.0 // Placeholder
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let cpuLoadInfo = info.bindMemory(to: processor_cpu_load_info.self, capacity: Int(numCpus))
        
        var totalUser: UInt32 = 0
        var totalSystem: UInt32 = 0
        var totalIdle: UInt32 = 0
        
        for i in 0..<Int(numCpus) {
            totalUser += cpuLoadInfo[i].cpu_ticks.0
            totalSystem += cpuLoadInfo[i].cpu_ticks.1
            totalIdle += cpuLoadInfo[i].cpu_ticks.2
        }
        
        let totalTicks = totalUser + totalSystem + totalIdle
        let usedTicks = totalUser + totalSystem
        
        info.deallocate()
        
        return totalTicks > 0 ? Double(usedTicks) / Double(totalTicks) : 0.0
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0 }
        return info.resident_size
    }
    
    private func getCurrentBatteryLevel() -> Float? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    private func logPerformanceWarnings(_ metrics: PerformanceMetrics) {
        if metrics.cpuUsage > 0.8 {
            logger.warning("High CPU usage: \(metrics.cpuUsage * 100)%")
        }
        
        if metrics.thermalState != .nominal {
            logger.warning("Thermal throttling detected: \(metrics.thermalState)")
        }
        
        if let batteryLevel = metrics.batteryLevel, batteryLevel < 0.2 {
            logger.warning("Low battery: \(batteryLevel * 100)%")
        }
    }
}