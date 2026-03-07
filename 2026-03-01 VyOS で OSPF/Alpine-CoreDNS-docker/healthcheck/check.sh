#!/bin/bash

# --- 設定変数 ---
VIP="${VIP:-100.64.255.10}"
CHECK_DOMAIN="${CHECK_DOMAIN:-google.com}"
MAX_RETRIES=3
SLEEP_INTERVAL=5
OSPF_AREA="${OSPF_AREA:-0.0.0.10}"
CONTAINER_NAME="coredns"
FRR_SOCKET_DIR="/var/run/frr"

# 状態管理フラグ
FAIL_COUNT=0
IS_ADVERTISING=true

# --- 関数定義 ---

# FRRにOSPF広報開始コマンドを送る
frr_advertise() {
    echo "$(date): OSPF広報を開始します (VIP: $VIP, Area: $OSPF_AREA)"
    # vtyshを介してFRRデーモンに設定を投入
    docker exec frr vtysh -c "configure terminal" \
        -c "router ospf" \
        -c "network $VIP/32 area $OSPF_AREA"
    IS_ADVERTISING=true
}

# FRRからOSPF広報停止コマンドを送る（経路撤回）
frr_withdraw() {
    echo "$(date): OSPF広報を停止します (VIP: $VIP)"
    docker exec frr vtysh -c "configure terminal" \
        -c "router ospf" \
        -c "no network $VIP/32 area $OSPF_AREA"
    IS_ADVERTISING=false
}

# CoreDNSコンテナを再起動する
restart_coredns() {
    echo "$(date): CoreDNSコンテナを再起動します..."
    docker restart $CONTAINER_NAME
    # 起動待ち時間を確保
    sleep 10
}

# DNSクエリテスト
check_dns() {
    # VIPに対してdigを実行。タイムアウト2秒、試行1回。
    dig @$VIP $CHECK_DOMAIN +time=2 +tries=1 > /dev/null 2>&1
    return $?
}

# --- メイン処理 ---
echo "DNSヘルスチェック・自動復旧監視を開始します..."

# 初期化：起動時は広報を試みる（Fail-Open思想）
frr_advertise

while true; do
    if check_dns; then
        # --- 正常時 ---
        if [ "$FAIL_COUNT" -ne 0 ]; then
            echo "$(date): DNSサービスが復旧しました。"
            FAIL_COUNT=0
        fi

        # 広報が停止していた場合は再開
        if [ "$IS_ADVERTISING" = false ]; then
            frr_advertise
        fi

    else
        # --- 異常時 ---
        FAIL_COUNT=$((FAIL_COUNT+1))
        echo "$(date): ヘルスチェック失敗 ($FAIL_COUNT/$MAX_RETRIES)"

        if [ "$FAIL_COUNT" -ge "$MAX_RETRIES" ]; then
            echo "$(date): 失敗回数が閾値に達しました。復旧アクションを実行します。"
            
            # 1. OSPF広報の停止（トラフィック遮断）
            if [ "$IS_ADVERTISING" = true ]; then
                frr_withdraw
            fi

            # 2. CoreDNSコンテナの再起動
            restart_coredns
            
            # 3. カウンタのリセット
            # 再起動後、次のループで再度チェックが行われる。
            # 成功すれば広報が再開され、失敗すれば再度カウントが始まる。
            FAIL_COUNT=0 
        else
            # リトライ待機
            sleep $SLEEP_INTERVAL
        fi
    fi

    # 定常監視間隔
    sleep $SLEEP_INTERVAL
done
