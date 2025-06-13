import SwiftUI
import IOKit.ps
import Combine
import AppKit

// 언어 감지 함수 (전역)
func isKoreanLanguage() -> Bool {
    Locale.current.language.languageCode?.identifier == "ko"
}

@main
struct batteryGoApp: App {
    @State private var batteryPercentage: Int = BatteryInfo.currentPercentage()
    @State private var isLowPowerMode: Bool = BatteryInfo.isLowPowerModeEnabled()
    @State private var showPercentage: Bool = false
    @State private var powerSource: String = BatteryInfo.powerSource()
    @State private var isCharging: Bool = BatteryInfo.isCharging()
    @State private var fullyCharged: Bool = BatteryInfo.fullyCharged()
    let refreshTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    var body: some Scene {
        MenuBarExtra {
            if isCharging {
                let timeToFull = BatteryInfo.timeRemainingUntilFull()
                let timeToFullText = (timeToFull == "계산 중" ? (isKoreanLanguage() ? "계산 중" : "Calculating") : (isKoreanLanguage() ? timeToFull : localizedTimeString(timeToFull)))
                Button(isKoreanLanguage() ? "충전 완료까지: \(timeToFullText)" : "Time to Full: \(timeToFullText)") {
                    // 아무 동작 없음
                }
            }
            if (powerSource == (isKoreanLanguage() ? "배터리" : "Battery")) {
                let usageTime = BatteryInfo.estimatedUsageTime()
                let usageTimeText = (usageTime == "계산 중" ? (isKoreanLanguage() ? "계산 중" : "Calculating") : (isKoreanLanguage() ? usageTime : localizedTimeString(usageTime)))
                Button(isKoreanLanguage() ? "남은 사용 시간: \(usageTimeText)" : "Time Remaining: \(usageTimeText)") {
                    // 아무 동작 없음
                }
            }
            Button(isKoreanLanguage() ? "전원 소스: \(powerSource)" : "Power Source: \(powerSource)") {
                // 아무 동작 없음
            }
            if powerSource == (isKoreanLanguage() ? "어댑터" : "Power Adapter") && !isCharging {
                Text(isKoreanLanguage() ? "충전중이 아님" : "Battery is not charging")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
//            Button(isKoreanLanguage() ? "배터리 상태: \(batteryCondition)" : "Battery Condition: \(batteryCondition)") {
//                // 아무 동작 없음
//            }
            Divider()
            Toggle(isKoreanLanguage() ? "퍼센트 숨기기" : "Hide Percentage", isOn: $showPercentage)
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
            Button(isKoreanLanguage() ? "배터리 설정..." : "Battery Settings...") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
            Button(isKoreanLanguage() ? "종료" : "Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            HStack(spacing: 4) {
                if powerSource == (isKoreanLanguage() ? "어댑터" : "Power Adapter") {
                    if isCharging {
                        Image(systemName: "bolt.fill") // 충전 중
                            .imageScale(.small)
                    } else if fullyCharged {
                        Image(systemName: "bolt") // 완충/충전 안함
                            .imageScale(.small)
                            .rotationEffect(.degrees(-90))
                    } else {
                        Image(systemName: "bolt") // 충전 안함(어댑터 연결)
                            .imageScale(.small)
                            .rotationEffect(.degrees(-90))
                    }
                }
                // 배터리 사용 중에는 아무 아이콘도 안 보임(원하면 배터리 아이콘 추가 가능)
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
                powerSource = BatteryInfo.powerSource()
                isCharging = BatteryInfo.isCharging()
                fullyCharged = BatteryInfo.fullyCharged()
            }
        }
        .menuBarExtraStyle(.menu)
    }

    func localizedTimeString(_ str: String) -> String {
        if isKoreanLanguage() { return str }
        // '6시간 20분' -> '6h 20m'
        return str.replacingOccurrences(of: "시간", with: "h").replacingOccurrences(of: "분", with: "m")
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
              let time = description[kIOPSTimeToFullChargeKey as String] as? Int,
              time >= 0 else {
            print("[BatteryInfo] timeRemainingUntilFull: 계산 중 (값 없음 또는 음수)")
            return "계산 중"
        }
        let h = time / 60
        let m = time % 60
        let result = h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
        print("[BatteryInfo] timeRemainingUntilFull: \(result)")
        return result
    }

    static func estimatedUsageTime() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let time = description[kIOPSTimeToEmptyKey as String] as? Int,
              time >= 0 else {
            print("[BatteryInfo] estimatedUsageTime: 계산 중 (값 없음 또는 음수)")
            return "계산 중"
        }
        let h = time / 60
        let m = time % 60
        let result = h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
        print("[BatteryInfo] estimatedUsageTime: \(result)")
        return result
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

    static func powerSource() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let ps = description[kIOPSPowerSourceStateKey as String] as? String else {
            return "-"
        }
        if ps == kIOPSACPowerValue { return isKoreanLanguage() ? "어댑터" : "Power Adapter" }
        if ps == kIOPSBatteryPowerValue { return isKoreanLanguage() ? "배터리" : "Battery" }
        return ps
    }

    static func batteryCondition() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let cond = description[kIOPSBatteryHealthKey as String] as? String else {
            return "-"
        }
        if isKoreanLanguage() {
            switch cond {
            case "Good": return "정상"
            case "Fair": return "양호"
            case "Poor": return "주의"
            default: return cond
            }
        }
        return cond
    }

    static func fullyCharged() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let charged = description["FullyCharged"] as? Bool else {
            return false
        }
        return charged
    }
}
