#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
作成者：サイトラボ
URL：https://www.site-lab.jp/
URL：https://buildree.com/

注意点：conohaのポートは全て許可前提となります。もしくは80番、443番の許可をしておいてください。システムのfirewallはオン状態となります。centosユーザーのパスワードはランダム生成となります。最後に表示されます

目的：grafanaのインストール
・grafana

COMMENT


start_message(){
echo ""
echo "======================開始======================"
echo ""
}

end_message(){
echo ""
echo "======================完了======================"
echo ""
}

#CentOS7か確認
if [ -e /etc/redhat-release ]; then
    DIST="redhat"
    DIST_VER=`cat /etc/redhat-release | sed -e "s/.*\s\([0-9]\)\..*/\1/"`

    if [ $DIST = "redhat" ];then
      if [ $DIST_VER = "8" ] || [ $DIST_VER = "9" ];then
        #EPELリポジトリのインストール
        start_message
        dnf remove -y epel-release
        dnf -y install epel-release
        end_message


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
        start_message
        echo "dnf updateを実行します"
        dnf -y update
        end_message

        #インストール
        start_message
        echo 'grafanaをインストールします'
        echo dnf install grafana -y
        dnf install grafana -y
        end_message

        #起動
        start_message
        echo 'systemctl start grafana-server'
        systemctl start grafana-server
        echo '自動起動'
        echo 'enable grafana-server'
        systemctl enable grafana-server

        #ユーザー作成
        start_message
        echo "unicornユーザーを作成します"
        USERNAME='unicorn'
        PASSWORD=$(more /dev/urandom  | tr -d -c '[:alnum:]' | fold -w 10 | head -1)

        echo "${PASSWORD}" | passwd --stdin "${USERNAME}"
        echo "パスワードは"${PASSWORD}"です。"


        #firewallのポート許可
        echo "3000番ポートを許可してます"
        start_message
        firewall-cmd --add-port=3000/tcp --permanent
        echo ""
        echo "保存して有効化"
        echo ""
        firewall-cmd --reload

        echo ""
        echo "設定を表示"
        echo ""
        firewall-cmd --list-all
        end_message

        umask 0002

        cat <<EOF
        http://IPアドレス:3000
        https://IPアドレス:3000
        で確認してみてください


        -----------------

EOF

        echo "unicornユーザーのパスワードは"${PASSWORD}"です。"

      else
        echo "対象OSではないため、このスクリプトは使えません。"
      fi
    fi

else
  echo "対象OSではないため、このスクリプトは使えません。"
  cat <<EOF
  検証LinuxディストリビューションはDebian・Ubuntu・Fedora・Arch Linux（アーチ・リナックス）となります。
EOF
fi


exec $SHELL -l
