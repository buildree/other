#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
作成者：サイトラボ
URL：https://www.site-lab.jp/
URL：https://buildree.com/

対象：AlmaLinux、Rocky Linux、RHEL、CentOS Stream、Oracle Linux (8/9/10系)

注意点：conohaのポートは全て許可前提となります。もしくは80番、443番の許可をしておいてください。システムのfirewallはオン状態となります。unicornユーザーはSSH鍵認証(ed25519)で作成され、秘密鍵/公開鍵のパスは最後にサマリーとして表示・保存されます

目的：grafanaのインストール
・grafana

COMMENT

EXECUTED_STEPS=""
WARNINGS=""

start_message(){
echo ""
echo "======================開始: $1 ======================"
echo ""
EXECUTED_STEPS="${EXECUTED_STEPS}- $1"$'\n'
}

end_message(){
echo ""
echo "======================完了: $1 ======================"
echo ""
}

warn_message(){
echo "警告: $1"
WARNINGS="${WARNINGS}- $1"$'\n'
}

# ディストリビューションとバージョンの検出
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DIST_ID=$ID
    DIST_VERSION_ID=$VERSION_ID
    DIST_NAME=$NAME
    # メジャーバージョン番号の抽出（8.10から8を取得）
    DIST_MAJOR_VERSION=$(echo "$VERSION_ID" | cut -d. -f1)
elif [ -f /etc/redhat-release ]; then
    if grep -q "CentOS Stream" /etc/redhat-release; then
        DIST_ID="centos-stream"
        DIST_VERSION_ID=$(grep -o -E '[0-9]+(\.[0-9]+)?' /etc/redhat-release | head -1)
        DIST_MAJOR_VERSION=$(echo "$DIST_VERSION_ID" | cut -d. -f1)
        DIST_NAME="CentOS Stream"
    else
        DIST_ID="redhat"
        DIST_VERSION_ID=$(grep -o -E '[0-9]+(\.[0-9]+)?' /etc/redhat-release | head -1)
        DIST_MAJOR_VERSION=$(echo "$DIST_VERSION_ID" | cut -d. -f1)
        DIST_NAME=$(cat /etc/redhat-release)
    fi
else
    warn_message "サポートされていないディストリビューションです"
    exit 1
fi

echo "検出されたディストリビューション: $DIST_NAME $DIST_VERSION_ID"

# Redhat系で8、9または10の場合のみ処理を実行
if [ -e /etc/redhat-release ] && [[ "$DIST_MAJOR_VERSION" -eq 8 || "$DIST_MAJOR_VERSION" -eq 9 || "$DIST_MAJOR_VERSION" -eq 10 ]]; then

        #EPELリポジトリのインストール
        start_message "EPELリポジトリのインストール"
        dnf remove -y epel-release
        dnf -y install epel-release
        end_message "EPELリポジトリのインストール"


        #リポジトリ追加
        cat >/etc/yum.repos.d/grafana.repo <<'EOF'
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

        #アップデート
        start_message "システムアップデート"
        echo "dnf updateを実行します"
        dnf -y update
        end_message "システムアップデート"

        #インストール
        start_message "grafanaインストール"
        echo 'grafanaをインストールします'
        echo dnf install grafana -y
        dnf install grafana -y
        end_message "grafanaインストール"

        #起動
        start_message "grafanaサービスの起動"
        echo 'systemctl start grafana-server'
        systemctl start grafana-server
        echo '自動起動'
        echo 'enable grafana-server'
        systemctl enable grafana-server
        end_message "grafanaサービスの起動"

        #ユーザー作成
        start_message "unicornユーザーの作成"
        echo "unicornユーザーを作成します"

        USERNAME='unicorn'
        PASSWORD=$(< /dev/urandom tr -dc '[:alnum:]' | head -c32)

        useradd -m -s /bin/bash $USERNAME
        if [ $? -ne 0 ]; then
            echo "ユーザー作成に失敗しました。"
            exit 1
        fi
        echo "$PASSWORD" | passwd --stdin $USERNAME

        mkdir -p /home/${USERNAME}/.ssh
        chmod 700 /home/${USERNAME}/.ssh
        ssh-keygen -t ed25519 -N "" -f /home/${USERNAME}/.ssh/${USERNAME}
        chmod 644 /home/${USERNAME}/.ssh/${USERNAME}.pub
        chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh
        cat /home/${USERNAME}/.ssh/${USERNAME}.pub >> /home/${USERNAME}/.ssh/authorized_keys
        chmod 600 /home/${USERNAME}/.ssh/authorized_keys
        chmod 600 /home/${USERNAME}/.ssh/${USERNAME}
        cp /home/${USERNAME}/.ssh/${USERNAME} /home/${USERNAME}/
        chown ${USERNAME}:${USERNAME} /home/${USERNAME}/${USERNAME}
        rm /home/${USERNAME}/.ssh/${USERNAME}

        echo "ed25519 SSH鍵が生成されました。"
        echo "秘密鍵: /home/${USERNAME}/${USERNAME}"
        echo "公開鍵: /home/${USERNAME}/.ssh/${USERNAME}.pub"
        echo "秘密鍵が /home/${USERNAME}/${USERNAME} に移動されました。"
        echo "秘密鍵のパーミッションは 600 に設定されています。"
        echo "このファイルを安全な方法でクライアントマシンに移動し、サーバーからは削除することを強く推奨します。"
        echo "秘密鍵はサーバー上に保管せず、使用するクライアントマシンにのみ保管してください。"
        echo "公開鍵をクライアントマシンの ~/.ssh/authorized_keys ファイルに追加してください。"
        echo "必要に応じて、秘密鍵にパスフレーズを設定してください。"
        echo "ユーザーのパスワードはランダムで生成されています。セキュリティの関係上表示したりファイルに残していないので新しく設定してください。"
        end_message "unicornユーザーの作成"

        #firewallのポート許可
        start_message "ファイアウォール設定"
        echo "3000番ポートを許可してます"
        firewall-cmd --add-port=3000/tcp --permanent
        echo ""
        echo "保存して有効化"
        echo ""
        firewall-cmd --reload

        echo ""
        echo "設定を表示"
        echo ""
        firewall-cmd --list-all
        end_message "ファイアウォール設定"

        umask 0002

        build_summary() {
            cat <<SUMMARYEOF
Buildree インストールサマリー - $(date '+%Y-%m-%d %H:%M:%S')

======================実行内容サマリー======================
${EXECUTED_STEPS}
======================作成・変更したファイル======================
- /etc/yum.repos.d/grafana.repo (grafanaリポジトリ定義)
- /home/unicorn 以下のユーザーホームディレクトリ一式
- /home/unicorn/.ssh/unicorn.pub (SSH公開鍵)
- /home/unicorn/.ssh/authorized_keys
- /home/unicorn/unicorn (SSH秘密鍵)
- firewalld 永続ルール: 3000/tcp を許可

======================unicornユーザーの認証情報======================
- ログイン方式: SSH鍵認証(ed25519)
- 秘密鍵: /home/unicorn/unicorn (パーミッション600)
- 公開鍵: /home/unicorn/.ssh/unicorn.pub
- OSログインパスワードはランダム生成後、画面表示・ファイル保存はしていません(セキュリティのため)。必要な場合は passwd unicorn で再設定してください。

======================警告======================
$( [ -n "$WARNINGS" ] && printf '%s' "$WARNINGS" || echo "警告はありませんでした" )

======================アクセス方法・注意事項======================
http://IPアドレス:3000
https://IPアドレス:3000
で確認してみてください
SUMMARYEOF
        }

        SUMMARY_TEXT=$(build_summary)
        echo "$SUMMARY_TEXT"
        echo "$SUMMARY_TEXT" > /home/unicorn/buildree_install_summary.txt
        chown unicorn:unicorn /home/unicorn/buildree_install_summary.txt
        chmod 600 /home/unicorn/buildree_install_summary.txt
        echo ""
        echo "このサマリーは /home/unicorn/buildree_install_summary.txt に保存されました。"

else
    warn_message "対象OSではないため、このスクリプトは使えません。"
    echo "エラー: このスクリプトはRHEL/CentOS/AlmaLinux/Rocky Linux/Oracle Linux 8、9または10専用です。"
    echo "検出されたOS: $DIST_NAME"
    echo "検出されたOSバージョン: $DIST_MAJOR_VERSION"
    exit 1
fi


exec $SHELL -l
