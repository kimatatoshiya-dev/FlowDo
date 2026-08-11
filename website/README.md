# FlowDo 公式サイト

GitHub Pages で公開する静的サイトです。Flutter アプリ本体とは独立した `website/` フォルダに配置しています。

## 構成

```
website/
├── index.html          # Home
├── privacy/index.html  # Privacy Policy（/privacy）
├── terms/index.html    # Terms of Service（/terms）
├── privacy.html        # → privacy/ へリダイレクト
├── terms.html          # → terms/ へリダイレクト
├── contact.html        # Contact
├── css/styles.css
├── js/nav.js
├── assets/logo.svg
├── .nojekyll
└── CNAME               # カスタムドメイン flowdo.app 用
```

## ローカル確認

```bash
cd website
python3 -m http.server 8080
```

ブラウザで http://localhost:8080 を開いてください。

## GitHub Pages 公開手順（公開時）

### 方法 A: `docs/` フォルダを使う（シンプル）

1. `website/` の中身を `docs/` にコピー（または Pages のソースを設定）
2. GitHub リポジトリ → **Settings → Pages**
3. **Source**: Deploy from a branch → `main` → **`/docs`**
4. カスタムドメイン `flowdo.app` を設定する場合は DNS で GitHub Pages を向ける

### 方法 B: `website/` のまま GitHub Actions でデプロイ

`.github/workflows/deploy-website.yml` を追加し、`website/` を artifact として Pages にデプロイします。

### カスタムドメイン

- `CNAME` に `flowdo.app` を記載済み
- DNS: `flowdo.app` → GitHub Pages（A レコードまたは CNAME）

## App Store URL の差し替え

`index.html` の App Store ボタン:

```html
<a class="store-button store-button--ready" href="https://apps.apple.com/app/idXXXXXXXXX">
  App Store で入手
</a>
```

公開前は `<button type="button" class="store-button" disabled>` になっています。公開時は `<a>` に差し替え、`store-button--ready` クラスを付与してください。

## アプリ側 URL

公開後、`lib/config/app_links.dart` の URL が本サイトと一致していることを確認してください。

- `https://flowdo.app/privacy`
- `https://flowdo.app/terms`

GitHub Pages のプロジェクト URL（`*.github.io/FlowDo/`）のみで公開する場合は、パス付き URL に合わせてアプリ側も更新が必要です。
