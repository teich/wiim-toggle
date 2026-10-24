// audio-device: tiny CoreAudio CLI for the WiiM toggle.
//
//   audio-device list                    UID<TAB>name of every output device
//   audio-device get-default             UID<TAB>name of the current default output
//   audio-device set-default <dev>       make <dev> the default output
//   audio-device get-volume <dev>        0-100, or "none" if not adjustable
//   audio-device set-volume <dev> <n>    set <dev>'s volume to n (0-100)
//
// <dev> is a device UID or its exact name.

import AudioToolbox
import CoreAudio
import Foundation

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

func address(_ selector: AudioObjectPropertySelector,
             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
    var addr = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr, let v = value else { return "" }
    return v.takeRetainedValue() as String
}

func outputDevices() -> [AudioObjectID] {
    var addr = address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids)
    return ids.filter { id in
        var streams = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var n: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &n) == noErr && n > 0
    }
}

func uid(_ id: AudioObjectID) -> String { stringProperty(id, kAudioDevicePropertyDeviceUID) }
func name(_ id: AudioObjectID) -> String { stringProperty(id, kAudioObjectPropertyName) }

func find(_ key: String) -> AudioObjectID {
    let devices = outputDevices()
    if let d = devices.first(where: { uid($0) == key }) ?? devices.first(where: { name($0) == key }) { return d }
    fail("no output device matching \"\(key)\"")
}

func defaultOutput() -> AudioObjectID {
    var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
    var id = AudioObjectID(0)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
    return id
}

func setDefaultOutput(_ id: AudioObjectID) {
    var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
    var dev = id
    let err = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                         UInt32(MemoryLayout<AudioObjectID>.size), &dev)
    if err != noErr { fail("could not set default output (\(err))") }
}

// The "virtual main volume" is what the menu bar slider and volume keys drive.
var volumeAddr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput)

func volume(_ id: AudioObjectID) -> Float32? {
    guard AudioObjectHasProperty(id, &volumeAddr) else { return nil }
    var v: Float32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)
    return AudioObjectGetPropertyData(id, &volumeAddr, 0, nil, &size, &v) == noErr ? v : nil
}

func setVolume(_ id: AudioObjectID, _ v: Float32) {
    var settable: DarwinBoolean = false
    guard AudioObjectHasProperty(id, &volumeAddr),
          AudioObjectIsPropertySettable(id, &volumeAddr, &settable) == noErr, settable.boolValue else {
        return  // fixed-level device (e.g. pure digital out): nothing to do
    }
    var value = max(0, min(1, v))
    let err = AudioObjectSetPropertyData(id, &volumeAddr, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    if err != noErr { fail("could not set volume (\(err))") }
}

let args = Array(CommandLine.arguments.dropFirst())
switch (args.first, args.count) {
case ("list", 1):
    for d in outputDevices() { print("\(uid(d))\t\(name(d))") }
case ("get-default", 1):
    let d = defaultOutput()
    print("\(uid(d))\t\(name(d))")
case ("set-default", 2):
    setDefaultOutput(find(args[1]))
case ("get-volume", 2):
    if let v = volume(find(args[1])) { print(Int((v * 100).rounded())) } else { print("none") }
case ("set-volume", 3):
    guard let n = Float32(args[2]) else { fail("volume must be a number 0-100") }
    setVolume(find(args[1]), n / 100)
default:
    fail("usage: audio-device list | get-default | set-default <dev> | get-volume <dev> | set-volume <dev> <0-100>")
}
