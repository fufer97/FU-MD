import Foundation

/// 版本号单一来源。
///
/// 打包脚本 `Scripts/build-app.sh` 从这里取值写入 `Info.plist` 的
/// `CFBundleShortVersionString`，发版脚本 `Scripts/release.sh` 也只改这一行，
/// 因此应用版本、安装包名与 GitHub Release 标签三处永远一致。
enum AppVersion {
    static let current = "0.1.3"
}
