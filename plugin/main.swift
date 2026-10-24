// WiiM Toggle: native Stream Deck plugin.
//
// Pressing the key runs ~/.local/bin/wiim-toggle. The key's state follows the
// Mac's default output wherever it gets changed: 0 = display, 1 = WiiM (USB SPDIF).

import CoreAudio
import Foundation

let spdifName = "USB SPDIF Audio"
let toggleScript = NSHomeDirectory() + "/.local/bin/wiim-toggle"
let logPath = NSHomeDirectory() + "/.local/state/wiim-toggle/plugin.log"

func log(_ msg: String) {
    let line = "\(Date()) \(msg)\n"
    if let h = FileHandle(forWritingAtPath: logPath) {
        h.seekToEndOfFile()
        h.write(line.data(using: .utf8)!)
        h.closeFile()
    } else {
        try? line.write(toFile: logPath, atomically: false, encoding: .utf8)
    }
}

// Stream Deck launches us with: -port N -pluginUUID X -registerEvent E -info JSON
var opts = [String: String]()
var argIter = CommandLine.arguments.dropFirst().makeIterator()
while let key = argIter.next(), let value = argIter.next() { opts[key] = value }
guard let port = opts["-port"], let pluginUUID = opts["-pluginUUID"], let registerEvent = opts["-registerEvent"] else {
    log("missing launch arguments: \(CommandLine.arguments)")
    exit(1)
}

func defaultOutputName() -> String {
    let system = AudioObjectID(kAudioObjectSystemObject)
    var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                          mScope: kAudioObjectPropertyScopeGlobal,
                                          mElement: kAudioObjectPropertyElementMain)
    var device = AudioObjectID(0)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &device) == noErr else { return "" }
    addr.mSelector = kAudioObjectPropertyName
    var name: Unmanaged<CFString>?
    size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &name) == noErr, let n = name else { return "" }
    return n.takeRetainedValue() as String
}

let socket = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)")!)
var contexts = Set<String>()  // visible keys; only touched on the main queue
var running = false

func send(_ message: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: message),
          let text = String(data: data, encoding: .utf8) else { return }
    socket.send(.string(text)) { error in if let error { log("send failed: \(error)") } }
}

func refresh() {
    let state = defaultOutputName() == spdifName ? 1 : 0
    log("state \(state) -> \(contexts.count) key(s)")
    for context in contexts { send(["event": "setState", "context": context, "payload": ["state": state]]) }
}

func toggle(_ context: String) {
    guard !running else { return }  // ignore presses while a switch is in flight
    running = true
    let process = Process()
    process.executableURL = URL(fileURLWithPath: toggleScript)
    process.terminationHandler = { p in
        DispatchQueue.main.async {
            running = false
            if p.terminationStatus != 0 {
                log("wiim-toggle exited \(p.terminationStatus)")
                send(["event": "showAlert", "context": context])
            }
            refresh()
        }
    }
    do {
        try process.run()
    } catch {
        running = false
        log("could not run \(toggleScript): \(error)")
        send(["event": "showAlert", "context": context])
    }
}

func handle(_ event: [String: Any]) {
    guard let name = event["event"] as? String else { return }
    let context = event["context"] as? String
    switch (name, context) {
    case ("willAppear", let c?): contexts.insert(c); refresh()
    case ("willDisappear", let c?): contexts.remove(c)
    case ("keyDown", let c?): log("keyDown"); toggle(c)
    case ("systemDidWakeUp", _): refresh()
    default: break
    }
}

func receive() {
    socket.receive { result in
        switch result {
        case .failure(let error):
            log("socket closed: \(error)")
            exit(0)
        case .success(.string(let text)):
            if let data = text.data(using: .utf8),
               let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async { handle(event) }
            }
            receive()
        case .success:
            receive()
        }
    }
}

// Keep the key in sync when the output changes from the menu bar, another app, or the script.
var defaultOutputAddr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                   mScope: kAudioObjectPropertyScopeGlobal,
                                                   mElement: kAudioObjectPropertyElementMain)
AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddr, DispatchQueue.main) { _, _ in
    refresh()
}

socket.resume()
send(["event": registerEvent, "uuid": pluginUUID])
receive()
log("started")
dispatchMain()
