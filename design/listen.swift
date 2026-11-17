// Measures what the Mac is asked to play: the peak level of all processes' audio output, second by
// second, and which processes have an output stream running. Usage: listen <seconds>
import CoreAudio
import Darwin
import Foundation

func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
}

func array<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, of: T.Type) -> [T] {
    var addr = address(selector)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(object, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    let count = Int(size) / MemoryLayout<T>.size
    let buffer = UnsafeMutablePointer<T>.allocate(capacity: count)
    defer { buffer.deallocate() }
    guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, buffer) == noErr else { return [] }
    return Array(UnsafeBufferPointer(start: buffer, count: count))
}

func value<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ initial: T) -> T? {
    var addr = address(selector)
    var size = UInt32(MemoryLayout<T>.size)
    var result = initial
    return AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &result) == noErr ? result : nil
}

func path(of pid: pid_t) -> String {
    var buffer = [CChar](repeating: 0, count: 4096)
    return proc_pidpath(pid, &buffer, 4096) > 0 ? String(cString: buffer) : "pid \(pid)"
}

/// Processes with an audio output stream running now.
func playing() -> [String] {
    array(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList, of: AudioObjectID.self).compactMap { object in
        guard value(object, kAudioProcessPropertyIsRunningOutput, UInt32(0)) == 1,
              let pid = value(object, kAudioProcessPropertyPID, pid_t(0)) else { return nil }
        return path(of: pid)
    }
}

let seconds = Int(CommandLine.arguments.dropFirst().first ?? "10") ?? 10
// Only processes whose path contains this are measured, so music playing elsewhere doesn't count.
let filter = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "CoreSimulator"
let mute = CommandLine.arguments.count > 3 && CommandLine.arguments[3] == "mute"

/// The Core Audio process objects to measure: they come and go as the simulator starts daemons.
func matching() -> [AudioObjectID] {
    array(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList, of: AudioObjectID.self).filter { object in
        value(object, kAudioProcessPropertyPID, pid_t(0)).map { path(of: $0).contains(filter) } ?? false
    }.sorted()
}

guard let output = value(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, AudioObjectID(0)) else { exit(1) }
var uidAddress = address(kAudioDevicePropertyDeviceUID)
var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
var uidRef: Unmanaged<CFString>?
guard AudioObjectGetPropertyData(output, &uidAddress, 0, nil, &uidSize, &uidRef) == noErr, let outputUID = uidRef?.takeRetainedValue() as String? else { exit(1) }
enum Output { nonisolated(unsafe) static var uid = "" }
Output.uid = outputUID

final class Meter: @unchecked Sendable { var peak: Float = 0; var frames = 0; let lock = NSLock() }
let meter = Meter()

/// One tap over a set of processes, with the device that reads it.
final class Tap {
    var tap = AudioObjectID(kAudioObjectUnknown)
    var device = AudioObjectID(kAudioObjectUnknown)
    var proc: AudioDeviceIOProcID?

    init?(_ objects: [AudioObjectID]) {
        let description = CATapDescription(stereoMixdownOfProcesses: objects)
        description.uuid = UUID()
        description.isPrivate = true
        // Muted: these processes' sound does not reach the Mac's speakers while the tap runs
        // (Apple's CATapMuteBehavior.muted). It is still measured.
        description.muteBehavior = mute ? .muted : .unmuted
        guard AudioHardwareCreateProcessTap(description, &tap) == noErr else { return nil }
        let uid = Output.uid
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "rainwatch-listen",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceMainSubDeviceKey: uid,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: uid]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: description.uuid.uuidString]],
        ]
        guard AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &device) == noErr else { return nil }
        let status = AudioDeviceCreateIOProcIDWithBlock(&proc, device, DispatchQueue(label: "listen")) { _, input, _, _, _ in
            var peak: Float = 0
            var frames = 0
            for buffer in UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)) {
                guard let data = buffer.mData else { continue }
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float32>.size
                let samples = data.assumingMemoryBound(to: Float32.self)
                for index in 0..<count { peak = max(peak, abs(samples[index])) }
                frames += count
            }
            meter.lock.lock(); meter.peak = max(meter.peak, peak); meter.frames += frames; meter.lock.unlock()
        }
        guard status == noErr, AudioDeviceStart(device, proc) == noErr else { return nil }
    }

    func stop() {
        AudioDeviceStop(device, proc)
        if let proc { AudioDeviceDestroyIOProcID(device, proc) }
        AudioHardwareDestroyAggregateDevice(device)
        AudioHardwareDestroyProcessTap(tap)
    }
}

func names(_ objects: [AudioObjectID]) -> [String] {
    objects.compactMap { value($0, kAudioProcessPropertyPID, pid_t(0)) }.map { (path(of: $0) as NSString).lastPathComponent }
}

let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
var overall: Float = 0
var everPlayed = Set<String>()
var everTapped = Set<String>()
var totalFrames = 0
var current: [AudioObjectID] = []
var tap: Tap?
var untapped = 0
// Ten looks a second, so a daemon that starts in order to play a sound is tapped before it plays.
for tick in 0..<(seconds * 10) {
    let objects = matching()
    if objects != current {
        tap?.stop()
        tap = objects.isEmpty ? nil : Tap(objects)
        current = objects
        everTapped.formUnion(names(objects))
        print("\(formatter.string(from: .now)) tapping \(objects.count): \(names(objects).joined(separator: ", "))\(tap == nil && !objects.isEmpty ? " TAP FAILED" : "")")
        if tap == nil, !objects.isEmpty { untapped += 1 }
    }
    usleep(100_000)
    guard tick % 10 == 9 else { continue }
    meter.lock.lock(); let peak = meter.peak; let frames = meter.frames; meter.peak = 0; meter.frames = 0; meter.lock.unlock()
    totalFrames += frames
    let now = playing().filter { $0.contains(filter) }
    everPlayed.formUnion(now)
    overall = max(overall, peak)
    if peak > 0 {
        print("\(formatter.string(from: .now)) peak \(String(format: "%.5f", peak)) playing: \(now.map { ($0 as NSString).lastPathComponent }.joined(separator: ", "))")
    }
}
tap?.stop()
print("TAPPED \(everTapped.sorted().joined(separator: ", ")); failed taps \(untapped)")
print("SUMMARY seconds \(seconds) frames \(totalFrames) overall peak \(String(format: "%.5f", overall))")
for path in everPlayed.sorted() { print("PLAYED \(path)") }
