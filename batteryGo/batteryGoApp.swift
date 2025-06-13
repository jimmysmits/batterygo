import SwiftUI
import IOKit.ps
import Combine
import AppKit


@main
struct batteryGoApp: App {
    @State private var batteryPercentage: Int = BatteryInfo.currentPercentage()
    @State private var isLowPowerMode: Bool = BatteryInfo.isLowPowerModeEnabled()
    @State private var showPercentage: Bool = false
    let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    var body: some Scene {
        MenuBarExtra {
            if BatteryInfo.isCharging() {
                Button("충전 완료까지: \(BatteryInfo.timeRemainingUntilFull())") {
                    // 아무 동작 없음
                }
            }
            Button("남은 사용 시간: \(BatteryInfo.estimatedUsageTime())") {
                // 아무 동작 없음
            }
            Divider()
            Toggle("퍼센트 숨기기", isOn: $showPercentage)
            //            Toggle("저전력 모드", isOn: Binding(
            //                get: { isLowPowerMode },
            //                set: { newValue in
            //                    BatteryInfo.setLowPowerMode(enabled: newValue) { success in
            //                        if success {
            //                            isLowPowerMode = newValue
            //                        } else {
            //                            isLowPowerMode = false
            //                            let alert = NSAlert()
            //                            alert.messageText = "관리자 권한이 필요합니다"
            //                            alert.informativeText = "저전력 모드 변경은 관리자 권한이 필요합니다. 시스템 환경설정에서 직접 변경해 주세요."
            //                            alert.addButton(withTitle: "배터리 설정 열기")
            //                            alert.addButton(withTitle: "취소")
            //                            let response = alert.runModal()
            //                            if response == .alertFirstButtonReturn {
            //                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
            //                                    NSWorkspace.shared.open(url)
            //                                }
            //                            }
            //                        }
            //                    }
            //                }
            //            ))
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
    //    static func setLowPowerMode(enabled: Bool, completion: @escaping (Bool) -> Void) {
    //        if #available(macOS 12.0, *) {
    //            let task = Process()
    //            task.launchPath = "/usr/bin/pmset"
    //            task.arguments = ["-a", "lowpowermode", enabled ? "1" : "0"]
    //            let pipe = Pipe()
    //            task.standardError = pipe
    //            do {
    //                try task.run()
    //                task.waitUntilExit()
    //                let success = (task.terminationStatus == 0)
    //                completion(success)
    //            } catch {
    //                completion(false)
    //            }
    //        } else {
    //            completion(false)
    //        }
    //    }
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
