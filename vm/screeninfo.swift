// screeninfo.swift: 各画面の見かけの大きさ（pt）と倍率（backingScaleFactor）を出す。
// VM の仮想画面では system_profiler SPDisplaysDataType の画面一覧が空になり、倍率を読めないため
// NSScreen から読む
import AppKit

for (i, s) in NSScreen.screens.enumerated() {
    let f = s.frame
    print("screen\(i): \(Int(f.width))x\(Int(f.height)) pt, backingScaleFactor=\(s.backingScaleFactor), main=\(s == NSScreen.main)")
}
if NSScreen.screens.isEmpty { print("no screens") }
