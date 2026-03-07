FROM alpine:latest

# 必要なパッケージのインストール
# bash: スクリプト実行用
# curl: HTTPヘルスチェック用（CoreDNSのhealthプラグイン確認用）
# bind-tools: digコマンド用（DNS応答確認用）
# docker-cli: ホスト上のDocker操作用
# coreutils: 高度なシェル機能用
RUN apk add --no-cache \
    bash \
    curl \
    bind-tools \
    docker-cli \
    coreutils

# スクリプトのコピーと権限設定
COPY healthcheck/check.sh /usr/local/bin/check.sh
RUN chmod +x /usr/local/bin/check.sh

# コンテナ起動時にスクリプトを実行
ENTRYPOINT ["/bin/bash", "/usr/local/bin/check.sh"]
