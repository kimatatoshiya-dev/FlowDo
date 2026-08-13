# FlowDo

考えずに入力。行動に集中。 — iOS 向けタスク管理アプリ（Flutter）

## 開発

```bash
flutter pub get
flutter test
flutter run
```

## 通常開発ルール

FlowDo の通常開発では、実機確認に次の方法のみ使用します。

- `flutter run`
- Xcode Run

通常開発では、次の方法は使用しません。

- `flutter install`
- `devicectl install`
- `flutter build ios --no-codesign`

これらはリリース前検証・調査専用とします。

---

## リリース前検証

通常開発では使用せず、起動・永続化・通知などの特別な検証時のみ実行します。

---

## Definition of Done

新機能は、次の条件をすべて満たした場合のみ「完成」とします。

- `flutter test` がすべて PASS
- `flutter run` または Xcode Run で実機起動確認
- iPhone 実機で手動動作確認
- Commit
- Push

---

## 開発方針

- 1機能 = 1フェーズ
- 実装 → テスト → 実機確認 → Commit → Push の順で進める
- 起動・永続化・通知などの基盤は、他機能と同時に変更しない
- 原因が特定できるまで推測で修正しない
- 変更は最小限とし、目的を明確にする
- 通常開発では診断コード・検証コードをコミットしない

---

公式サイトの静的ファイルは `website/` にあります（GitHub Pages 公開前）。

## Flutter公式Issueが解決したら削除予定のコード

- **iOS 起動ワークアラウンド** — `ios/Runner/FlowDoLaunchPrewarm.*` と `FlowDoFlutterViewController.*`、および `AppDelegate.swift` / `Main.storyboard` / `Runner-Bridging-Header.h` への組み込み。iOS 26 + ProMotion 端末で Storyboard 経由の Flutter 起動時に VSyncClient が落ちる既知問題への回避（[flutter#153971](https://github.com/flutter/flutter/issues/153971)、[flutter#187544](https://github.com/flutter/flutter/issues/187544)）。Flutter 公式修正後は `fix(ios): workaround for Flutter iOS26 ProMotion launch crash` コミットを revert するだけで戻せます。
