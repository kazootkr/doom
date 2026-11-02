// keysend.swift: ゲストにキーを送る。CGEvent を使うので、入力送出の権限だけで動く
// （osascript の System Events は、別の許可ダイアログが出て止まるため使わない）。
//
// 使い方: keysend KEY...
//   KEY は キー名 か 仮想キーコード（数字）。修飾キーは + でつなぐ（例: opt+x、ctrl+shift+a）
//   キー名: a〜z、0〜9、esc、ret、tab、space、del、left、right、up、down、home、end、
//           pageup、pagedown、kana、eisu、minus、slash、period、comma
//   修飾キー: shift、ctrl、opt（alt）、cmd
//   wait:MS で MS ミリ秒待つ。--flags で今の修飾の状態を出す（送らない）
import CoreGraphics
import Foundation

let names: [String: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
    "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "minus": 27, "8": 28, "0": 29,
    "o": 31, "u": 32, "i": 34, "p": 35, "ret": 36, "l": 37, "j": 38, "k": 40, "comma": 43,
    "slash": 44, "n": 45, "m": 46, "period": 47, "tab": 48, "space": 49, "del": 51,
    "esc": 53, "eisu": 102, "kana": 104, "home": 115, "pageup": 116, "end": 119,
    "pagedown": 121, "left": 123, "right": 124, "down": 125, "up": 126,
]
let modifiers: [String: (code: CGKeyCode, flag: CGEventFlags)] = [
    "shift": (56, .maskShift), "ctrl": (59, .maskControl),
    "opt": (58, .maskAlternate), "alt": (58, .maskAlternate), "cmd": (55, .maskCommand),
]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("keysend: \(message)\n".data(using: .utf8)!)
    exit(2)
}

let source = CGEventSource(stateID: .hidSystemState)

// 修飾フラグは毎回明示的に設定する。設定しないと、イベントはイベント元（hidSystemState）の今の
// 修飾の状態を引き継ぐ。矢印キーを送ると fn と NumericPad のビットがその状態に残り、後の文字キー
// にも fn が付いてしまう（d が音声入力の起動になる）
func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags, flagsChanged: Bool = false) {
    guard let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else {
        fail("イベントを作れません（キーコード \(code)）")
    }
    if flagsChanged { e.type = .flagsChanged }
    e.flags = flags
    e.post(tap: .cghidEventTap)
    usleep(30_000)
}

// 修飾キーは、押す・離すを flagsChanged として送る。キーのイベントにフラグを付けるだけだと、
// 離したことがシステムの修飾の状態に伝わらず、後のキーにも修飾が残るため
func send(_ token: String) {
    var parts = token.split(separator: "+").map(String.init)
    guard let keyName = parts.popLast(), !keyName.isEmpty else { fail("キーがありません: \(token)") }
    guard let code = names[keyName] ?? UInt16(keyName).flatMap({ $0 < 128 ? CGKeyCode($0) : nil })
    else { fail("知らないキーです: \(keyName)") }
    var flags: CGEventFlags = []
    var held: [(code: CGKeyCode, flag: CGEventFlags)] = []
    for name in parts {
        guard let m = modifiers[name] else { fail("知らない修飾キーです: \(name)") }
        flags.insert(m.flag)
        held.append(m)
        post(m.code, down: true, flags: flags, flagsChanged: true)
    }
    post(code, down: true, flags: flags)
    post(code, down: false, flags: flags)
    for m in held.reversed() {
        flags.remove(m.flag)
        post(m.code, down: false, flags: flags, flagsChanged: true)
    }
}

let args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty { fail("usage: keysend KEY...（例: keysend esc i kana a ret opt+x）") }
if args == ["--flags"] {
    print("flags=0x\(String(CGEventSource.flagsState(.hidSystemState).rawValue, radix: 16))")
    exit(0)
}
for token in args {
    if token.hasPrefix("wait:") {
        guard let ms = UInt32(token.dropFirst(5)) else { fail("wait の値が数字ではありません: \(token)") }
        usleep(ms * 1000)
    } else {
        send(token)
    }
}
