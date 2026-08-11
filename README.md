# FlowDo

考えずに入力。行動に集中。 — iOS 向けタスク管理アプリ（Flutter）

## 開発

```bash
flutter pub get
flutter test
flutter run
```

公式サイトの静的ファイルは `website/` にあります（GitHub Pages 公開前）。

## Flutter公式Issueが解決したら削除予定のコード

- **iOS 起動ワークアラウンド** — `ios/Runner/FlowDoLaunchPrewarm.*` と `FlowDoFlutterViewController.*`、および `AppDelegate.swift` / `Main.storyboard` / `Runner-Bridging-Header.h` への組み込み。iOS 26 + ProMotion 端末で Storyboard 経由の Flutter 起動時に VSyncClient が落ちる既知問題への回避（[flutter#153971](https://github.com/flutter/flutter/issues/153971)、[flutter#187544](https://github.com/flutter/flutter/issues/187544)）。Flutter 公式修正後は `fix(ios): workaround for Flutter iOS26 ProMotion launch crash` コミットを revert するだけで戻せます。
