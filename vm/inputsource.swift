// inputsource.swift: 今の入力ソースの ID を出す。--enabled で有効な入力ソースの一覧を出す。
// Emacs 以外のアプリが前面のときの入力ソース（Emacs から引き戻されていないか）を読むのに使う
import Carbon
import Foundation

func sourceID(_ source: TISInputSource) -> String {
    guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "?" }
    return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
}

if CommandLine.arguments.dropFirst().first == "--enabled" {
    let list = TISCreateInputSourceList(nil, false).takeRetainedValue() as! [TISInputSource]
    for id in list.map(sourceID).sorted() { print(id) }
} else {
    print(sourceID(TISCopyCurrentKeyboardInputSource().takeRetainedValue()))
}
