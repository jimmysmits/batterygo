import SwiftUI
import IOKit.ps
import Combine


@main
struct batteryGoApp: App {
    @State private var batteryPercentage: Int = BatteryInfo.currentPercentage()
    @State private var isLowPowerMode: Bool = BatteryInfo.isLowPowerModeEnabled()
    @State private var showPercentage: Bool = true
    let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    var body: some Scene {
        MenuBarExtra {
            Button("충전 완료까지: \(BatteryInfo.timeRemainingUntilFull())") {}
                .disabled(true)
            Button("남은 사용 시간: \(BatteryInfo.estimatedUsageTime())") {}
                .disabled(true)
            Divider()
            Toggle("퍼센트 숨기기", isOn: $showPercentage)
            Toggle("저전력 모드", isOn: Binding(
                get: { isLowPowerMode },
                set: { newValue in
                    isLowPowerMode = newValue
                    BatteryInfo.setLowPowerMode(enabled: newValue)
                }
            ))
            .disabled(!BatteryInfo.canControlLowPowerMode)
            Divider()
            Button("배터리 설정...") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            HStack(spacing: 4) {
                if BatteryInfo.isCharging() {
                    Image(systemName: "bolt.fill")
                        .imageScale(.small)
                }
                if showPercentage {
                    Text("\(batteryPercentage)")
                        .font(.system(size: 9))
                        .foregroundColor(isLowPowerMode ? .yellow : .primary)
                } else {
                    Text("\(batteryPercentage)%")
                        .font(.system(size: 9))
                        .foregroundColor(isLowPowerMode ? .yellow : .primary)
                }
            }
            .onReceive(refreshTimer) { _ in
                batteryPercentage = BatteryInfo.currentPercentage()
                isLowPowerMode = BatteryInfo.isLowPowerModeEnabled()
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct BatteryInfo {
    static func currentPercentage() -> Int {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let percent = description[kIOPSCurrentCapacityKey] as? Int,
              let max = description[kIOPSMaxCapacityKey] as? Int else { return 0 }
        return Int(Double(percent) / Double(max) * 100)
    }

    static func isLowPowerModeEnabled() -> Bool {
        if #available(macOS 12.0, *) {
            return ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        return false
    }
    static var canControlLowPowerMode: Bool {
        if #available(macOS 12.0, *) {
            return true
        }
        return false
    }
    static func setLowPowerMode(enabled: Bool) {
        if #available(macOS 12.0, *) {
            let task = Process()
            task.launchPath = "/usr/bin/pmset"
            task.arguments = ["-a", "lowpowermode", enabled ? "1" : "0"]
            try? task.run()
        }
    }
    static func timeRemainingUntilFull() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let minutes = description[kIOPSTimeToFullChargeKey] as? Int else {
            return "N/A"
        }
        return minutes > 0 ? "\(minutes)분" : "계산 중"
    }

    static func estimatedUsageTime() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let minutes = description[kIOPSTimeToEmptyKey] as? Int else {
            return "N/A"
        }
        return minutes > 0 ? "\(minutes / 60)시간 \(minutes % 60)분" : "계산 중"
    }


    static func isCharging() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let isCharging = description[kIOPSIsChargingKey] as? Bool else {
            return false
        }
        return isCharging
    }
}
