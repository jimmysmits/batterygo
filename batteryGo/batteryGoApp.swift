import SwiftUI
import IOKit.ps


@main
struct batteryGoApp: App {
    @State private var batteryPercentage: Int = BatteryInfo.currentPercentage()
    @State private var isLowPowerMode: Bool = BatteryInfo.isLowPowerModeEnabled()
    var body: some Scene {
        MenuBarExtra(content: {
            VStack(alignment: .leading, spacing: 8) {
                Text("충전 완료까지: \(BatteryInfo.timeRemainingUntilFull())")
                Text("남은 사용 시간: \(BatteryInfo.estimatedUsageTime())")
                Divider()
                Toggle("저전력 모드", isOn: Binding(
                    get: { isLowPowerMode },
                    set: { newValue in
                        isLowPowerMode = newValue
                        BatteryInfo.setLowPowerMode(enabled: newValue)
                    }
                ))
                .disabled(!BatteryInfo.canControlLowPowerMode)
                // macOS 배터리 패널과 유사하게 메뉴 맨 아래에 스타일 추가
                VStack(spacing: 4) {
                    Divider()
                    HStack {
                        Text("배터리 설정...")
                            .onTapGesture {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        // 좌측 정렬: Spacer 제거
                    }
                }
            }
            .padding()
            .frame(width: 250)
        }, label: {
            HStack(spacing: 4) {
                if BatteryInfo.isCharging() {
                    Image(systemName: "bolt.fill")
                        .imageScale(.small)
                }
                Text("\(batteryPercentage)%")
                    .font(.system(size: 9))
            }
        })
        .menuBarExtraStyle(.window)
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
