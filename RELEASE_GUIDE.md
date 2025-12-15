# GitHub Releases 作成ガイド

このガイドでは、GitHub Releasesを使って配布ファイルを公開する方法を説明します。

## 手順

### 1. GitHubでリリースを作成

1. [GitHubリポジトリ](https://github.com/k-aoshima/AetherDeck)にアクセス
2. 右側の「Releases」セクションをクリック
3. 「Create a new release」をクリック

### 2. リリース情報を入力

- **Tag version**: `v0.1.0` など、バージョン番号を入力
- **Release title**: `Aether Deck v0.1.0` など
- **Description**: リリースノートを記入（変更内容、新機能など）

### 3. 配布ファイルをアップロード

- 「Attach binaries」セクションで `Aether Deck-0.1.0-arm64.dmg.zip` をアップロード
- ファイルサイズが大きい（228MB）ため、アップロードに時間がかかる場合があります

### 4. リリースを公開

- 「Publish release」をクリックして公開

## 今後のリリース

新しいバージョンをリリースする際は、同じ手順で：

1. 新しいタグを作成（例: `v0.2.0`）
2. 新しい配布ファイルをアップロード
3. リリースノートを更新

## 注意事項

- 配布ファイルはリポジトリの履歴に含めない（GitHub Releasesのみにアップロード）
- ファイルサイズが大きいため、Git LFSの使用は推奨されません
- GitHub Releasesは無料アカウントでも利用可能
