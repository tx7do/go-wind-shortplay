<div align="center">

# GoWind ShortPlay

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Go Version](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go&logoColor=white)](https://go.dev/)
[![React](https://img.shields.io/badge/React-19.x-61DAFB?logo=react&logoColor=white)](https://react.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Kratos](https://img.shields.io/badge/Kratos-2.9-00ADD8?logo=go&logoColor=white)](https://go-kratos.dev/)

[English](./README.en-US.md) | [中文](./README.md) | **日本語**

</div>

---

風行短劇（GoWind ShortPlay）は、GoWind エコシステム上に構築された、すぐに使えるエンタープライズ級ショート動画コミュニティのベーシック版（オープンソース MVP）です。縦スワイプの没入型動画フィード、投稿、ソーシャルインタラクション、バックオフィス審査ループを備え、小規模トラフィックの企業内シナリオでそのまま本番稼働できます。

**主な特長：**

- **API ファースト** — Protobuf ファーストの契約駆動開発、RESTful / gRPC デュアルプロトコル、OpenAPI ドキュメント自動生成（Swagger 内蔵）
- **3 サービスアーキテクチャ** — admin / app の薄い BFF ゲートウェイ + 唯一のデータ投影先である core サービス。[go-wind-cms](https://github.com/tx7do/go-wind-cms) と完全に同型
- **2 つのフロントエンド** — React 19 管理画面（GoWind Admin ベースから派生）+ Flutter クロスプラットフォームアプリが、単一の core サービスを共有
- **すぐに使える** — `docker compose` 一発起動。core は初回起動時にテーブルを自動作成し、管理者アカウントをシード
- **商用版への拡張性** — トランスコードクラスタ、AI レコメンド、コンテンツモデレーション、SaaS マルチテナント、ライブ配信は独立サービスとして外付け。契約境界は既に確定（[docs/ROADMAP.md](./docs/ROADMAP.md) 参照）

> **オープンソース版 / 商用版の境界**：本リポジトリはオープンソースのベーシック版です。マルチビットレートトランスコードクラスタ、AI レコメンド、コンテンツモデレーション、SaaS マルチテナント、ライブ配信は含みません（商用クローズドソースのアドオンパックに属します）。

## テクノロジースタック

### バックエンド

| レイヤー | 技術 | 説明 |
|:---------|:-----|:-----|
| 言語 | [Go 1.26+](https://go.dev/) | 高性能コンパイル言語 |
| フレームワーク | [go-kratos](https://go-kratos.dev/) v2.9 | Bilibili 製マイクロサービスフレームワーク |
| 依存性注入 | 手書きアセンブリ（wiring.go） | DI フレームワークなし |
| ORM | [Ent](https://entgo.io/) v0.14 | スキーマ・アズ・コード |
| データベース | [PostgreSQL](https://www.postgresql.org/) / [MySQL](https://www.mysql.com/) | 両対応、pgx/v5 ドライバ |
| キャッシュ | [Redis](https://redis.io/) | カウンタ / 既視フィルタ / フィード重複排除 |
| オブジェクトストレージ | [MinIO](https://min.io/) | 動画 / カバー画像（S3 互換） |
| メディア処理 | FFmpeg | 単フレームのカバー抽出、プロセス内実行、欠落時は静かにフォールバック |
| API 定義 | [Protobuf](https://protobuf.dev/) + [buf.build](https://buf.build/) | 契約ファースト |
| 認証 | HS256 JWT | core で発行、ゲートウェイで検証、gRPC metadata で伝播 |

### 管理画面フロントエンド

| 技術 | 説明 |
|:-----|:-----|
| [React 19](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/) | モダン frontend フレームワーク + 型安全 |
| [Ant Design](https://ant.design/) + [ProComponents](https://procomponents.ant.design/) | エンタープライズ管理 UI（Ant Design Pro v6） |
| [TanStack Query](https://tanstack.com/query) | サーバー状態管理 |
| ビルドツール | [Vite](https://vite.dev/) 8（Node ≥ 20.19 必須） |

> 管理画面は go-wind-cms の Ant Design Pro ベースを切り出して適応させたものです：シェルと基盤（レイアウト / ルーティング / 認証 / i18n / トランスポート層）を保持し、ベースの既存パターンに沿ってショート動画コミュニティの業務モジュールを追加しています。

### モバイルアプリ

| 技術 | 説明 |
|:-----|:-----|
| [Flutter](https://flutter.dev/) 3.x | ワンコードベースで iOS / Android 両対応 |
| [BLoC](https://bloclibrary.dev/) | 状態管理 |
| [media_kit](https://media-kit.pro/) | 動画プレイヤー（没入型縦スワイプ） |

## アーキテクチャ

```
React Admin ──▶ admin-service (BFF :7600) ──┐
                                            ├──gRPC──▶ core-service (:7900, 唯一のデータ投影先)
Flutter App ──▶ app-service   (BFF :7700) ──┘              │
                                        PostgreSQL / Redis / MinIO / FFmpeg
```

- **admin / app は薄い BFF ゲートウェイ**（パラメータ検証 + 転送）。業務ロジックとデータ操作はすべて core に集約
- ドメイン分割は proto と core 内部モジュール（video / feed / interaction / report / uba / sysconf / notify / identity / stats）に反映され、プロセスには反映されない
- サービス分割の検討と商用版拡張パスは [docs/ROADMAP.md](./docs/ROADMAP.md) 参照

## コア機能

### 動画 & フィード

| 機能 | 説明 |
|:-----|:-----|
| 動画投稿 | チャンクアップロード（レジューム対応）、MinIO への統合登録、FFmpeg カバー抽出、下書き |
| ステートマシン | 下書き → 審査 → 公開 / 差し戻し → 非公開、遷移ホワイトリスト検証 |
| 没入型フィード | 縦スワイプ、3 系統のルールベースリコール（フォロー最新 / ホット加重 / 最新フォールバック）、Redis 既視重複排除 |
| 検索 & 集約 | タイトル部分一致 + タグ完全一致検索、タグ集約ページ、タグ一覧（投稿時選択 / 検索サジェスト） |

### インタラクション & コミュニティ

| 機能 | 説明 |
|:-----|:-----|
| いいね / お気に入り | 動画・コメントへのいいね、動画のお気に入り |
| フォロー | フォロー / ファン一覧、プロフィール |
| コメント | 動画コメント（ネスト返信フィールドを予約） |
| 通知 | いいね / コメント / フォロー / システム通知 |
| 通報ループ | ユーザー通報チケット。承認すると対象コンテンツの処分（非公開 / 削除）に連動 |
| UBA トラッキング | 視聴 / 完視聴 / スキップ行動の収集、フィードランキングに反映 |
| クリエイター統計 | 投稿数 / 受たいいいね / フォロワーなどの指標 |
| シェア | シェア用 H5 ランディングページ |

### 管理画面

| 機能 | 説明 |
|:-----|:-----|
| 動画管理 | 審査 / 差し戻し / 非公開 / 削除、状態遷移の可視化 |
| コメント管理 | コメント照会・削除 |
| 通報チケット | 通報の受付・処分、処分は対象コンテンツに連動 |
| ユーザー管理 | ユーザー照会・管理 |
| ダッシュボード | 主要指標の概観 |
| システム設定 | アップロード制限 / 長さ制限 / 手動審査スイッチ |

## プロジェクト構造

```
go-wind-shortplay/
├── backend/                        # バックエンドサービス
│   ├── api/                        # Protobuf API 定義 & 生成コード
│   │   ├── protos/                 # .proto ソース（video/feed/interaction/... 各ドメイン + admin/app BFF）
│   │   └── gen/go/                 # 生成コード（HTTP/gRPC/検証）、手動修正禁止
│   ├── app/
│   │   ├── admin/service/          # 管理画面サービス（BFF、REST :7600）
│   │   ├── app/service/            # クライアントアプリサービス（BFF、REST :7700）
│   │   └── core/service/           # コア業務サービス（ロジック + データ層、gRPC :7900）
│   ├── pkg/                        # 共有パッケージ（認証コンテキスト/ミドルウェア/OSS/サービスディスカバリ...）
│   ├── Makefile / app.mk           # ビルドオーケストレーション
│   └── docker-compose.yaml         # コンテナデプロイ（アプリサービス 3 つ）
├── frontend/
│   ├── admin/                      # 管理画面フロントエンド（React 19 + Ant Design Pro v6、dev :16800）
│   └── app/                        # Flutter アプリ（BLoC + media_kit）
└── docs/                           # ドキュメント（API 契約サマリ、アーキテクチャ決定）
```

## クイックスタート

### 前提条件

- Go 1.26+
- Docker & Docker Compose
- Node.js ≥ 20.19 & pnpm（Vite 8 の要件）
- Flutter 3.x
- buf（Protobuf ツールチェーン、`make init` で自動インストール可）

### 1. 依存サービスの準備

PostgreSQL / Redis / MinIO / Kafka はホスト上の既存コンテナを再利用します。ZLMediaKit は `docker run` で別途作成し、PostgreSQL に `shortplay` データベースを作成してください：

```bash
docker run -d --name shortplay-zlmediakit --restart unless-stopped \
  -p 8280:80 -p 8444:443 -p 8555:554 -p 8935:1935 -p 8200:8000/udp -p 11001:10000 \
  -v shortplay_zlm_data:/opt/media/bin/data \
  zlmediakit/zlmediakit:master
```

```sql
CREATE DATABASE shortplay;
```

### 2. 初期化とバックエンド起動

```bash
cd backend
make init        # 初回：protoc プラグインと CLI ツールチェーンをインストール

make gen         # ent + api + openapi を一括生成
cd app/core/service  && make run   # gRPC :7900（起動時にテーブル自動作成・管理者シード）
cd app/admin/service && make run   # REST :7600
cd app/app/service   && make run   # REST :7700
```

依存接続パラメータは `configs/*.yaml` の `${ENV:default}` 補間を環境変数で上書きできます（`DB_HOST` / `DB_PORT` / `DB_NAME` / `REDIS_ADDR` / `OSS_ENDPOINT` / `JWT_SIGNING_KEY` など）。

動作確認：

```bash
curl -X POST http://127.0.0.1:7700/app/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo","password":"demo123","nickname":"Demo"}'
```

API ドキュメント：サービス起動後、`http://127.0.0.1:7600/docs/` と `http://127.0.0.1:7700/docs/`（Swagger）にアクセスしてください。

### 3. フロントエンドの起動

```bash
# 管理画面
cd frontend/admin
pnpm install
pnpm dev         # dev :16800。デモアカウント admin / admin（core 初回起動時にシード）

# Flutter アプリ
cd frontend/app
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:7700   # Android エミュレータは既定 10.0.2.2
```

### よく使うコマンド

```bash
cd backend

make init        # protoc プラグインと CLI のインストール（初回）
make api         # buf generate（proto → Go）
make openapi     # admin/app の OpenAPI ドキュメントを assets/ に生成
make ent         # ent コード生成（各サービス）
make gen         # ent + api + openapi を一括生成
make build       # 全サービスビルド
make test        # go test ./...
make lint        # golangci-lint
```

### コンテナデプロイ

```bash
cd backend
docker compose up -d --build
```

> 開発ワークフローの詳細は[バックエンド開発ガイド](./backend/AGENTS.md)を参照してください。

## ドキュメント

- ルート README（3 言語）：[README.md](./README.md) / [README.en-US.md](./README.en-US.md) / [README.ja-JP.md](./README.ja-JP.md)
- バックエンド開発ガイド：[backend/AGENTS.md](./backend/AGENTS.md) — AI コーディングツールと人間のコントリビュータ共通
- 管理画面：[frontend/admin/AGENTS.md](./frontend/admin/AGENTS.md)
- Flutter アプリ：[frontend/app/AGENTS.md](./frontend/app/AGENTS.md)
- REST API 契約サマリ：[docs/API.md](./docs/API.md)
- アーキテクチャ決定 & サービス分割検討：[docs/ROADMAP.md](./docs/ROADMAP.md)

## お問い合わせ

- WeChat：`yang_lin_bo`（備考：`go-wind-shortplay`）

## コントリビューション

次のような、あらゆる形の貢献を歓迎します：

- [Issue](../../issues) によるバグ報告や機能提案
- [Pull Request](../../pulls) による修正・機能追加
- ドキュメントと翻訳の改善
- 使用経験の共有

詳細は [CONTRIBUTING.md](./CONTRIBUTING.md) を参照してください。

## ライセンス

本プロジェクトは [MIT License](./LICENSE) の下で公開されています。

## 謝辞

[![JetBrains](https://resources.jetbrains.com/storage/products/company/brand/logos/jb_beam.svg)](https://jb.gg/OpenSource)

無料の GoLand & WebStorm オープンソースライセンスを提供してくださっている [JetBrains](https://jb.gg/OpenSource) に感謝します。
