#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
作成者：サイトラボ
URL：https://www.site-lab.jp/
URL：https://buildree.com/

注意点：conohaのポートは全て許可前提となります。もしくは80番、443番の許可をしておいてください。システムのfirewallはオン状態となります。centosユーザーのパスワードはランダム生成となります。最後に表示されます

目的：システム更新+cockpitのインストール
・cockpitのインストール
・centosユーザーの作成

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
      if [ $DIST_VER = "7" ];then
        #EPELリポジトリのインストール
        start_message
        yum remove -y epel-release
        yum -y install epel-release
        end_message


        #gitリポジトリのインストール
        start_message
        yum -y install git
        end_message


        # yum updateを実行
        start_message
        echo "システムを更新します"
        echo ""
        yum -y update
        end_message


        #ユーザー作成
        start_message
        wget wget https://www.logw.jp/download/shell/common/user/useradd.sh
        source ./useradd.sh




        #cockpitのインストール
        start_message
        echo "cockpitのインストール"
        echo "yum -y install cockpit"
        yum -y install cockpit
        end_message

        #cockpitの起動
        start_message
        echo "コックピットの起動をします"
        echo "systemctl start cockpit.socket"
        systemctl start cockpit.socket
        echo "起動確認をします"
        echo "systemctl status cockpit.socket"
        systemctl status cockpit.socket
        end_message

        #自動起動の設定
        start_message
        echo "コックピットの起動をします"
        echo "systemctl enable cockpit.socket"
        systemctl enable cockpit.socket
        systemctl list-unit-files --type=service | grep cockpit
        end_message



        #firewallのポート許可
        echo "9090の許可をしてます"
        start_message
        firewall-cmd --add-port=9090/tcp --permanent
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
        http://IPアドレス:9090/
        https://IPアドレス:9090/
        で確認してみてください


        -----------------

EOF

        echo "centosユーザーのパスワードは"${PASSWORD}"です。"

      else
        echo "CentOS7ではないため、このスクリプトは使えません。このスクリプトのインストール対象はCentOS7です。"
      fi
    fi

else
  echo "このスクリプトのインストール対象はCentOS7です。CentOS7以外は動きません。"
  cat <<EOF
  検証LinuxディストリビューションはDebian・Ubuntu・Fedora・Arch Linux（アーチ・リナックス）となります。
EOF
fi


exec $SHELL -l
