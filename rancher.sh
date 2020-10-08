#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
作成者：サイトラボ
URL：https://www.site-lab.jp/
URL：https://buildree.com/

注意点：conohaのポートは全て許可前提となります。もしくは80番、443番の許可をしておいてください。システムのfirewallはオン状態となります。centosユーザーのパスワードはランダム生成となります。最後に表示されます

目的：システム更新+nginxのインストール
・nginx
・mod_sslのインストール
・gogsのインストール
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

        #Dockerのインストール
        start_message
        echo "Dockerのインストールをします"
        yum install -y yum-utils device-mapper-persistent-data  lvm2
        yum-config-manager --add-repo -y https://download.docker.com/linux/centos/docker-ce.repo
        yum makecache fast
        echo "最新版をインストールします"
        yum install docker-ce
        end_message


        # yum updateを実行
        echo "yum updateを実行します"
        echo ""

        start_message
        yum -y update
        end_message


        #ユーザー作成
        start_message
        echo "centosユーザーを作成します"
        USERNAME='centos'
        PASSWORD=$(more /dev/urandom  | tr -d -c '[:alnum:]' | fold -w 10 | head -1)

        echo "${PASSWORD}" | passwd --stdin "${USERNAME}"
        echo "パスワードは"${PASSWORD}"です。"




        #Dockerの起動
        start_message
        echo "Dockerの起動"
        echo ""
        systemctl start docker
        systemctl status docker
        end_message

        #自動起動の設定
        start_message
        systemctl enable docker
        systemctl list-unit-files --type=service | grep docker
        end_message

        #Rancherのインストール
        start_message
        echo "Rancherのインストールを実行します"
        docker run -d --restart=unless-stopped -p 80:80 -p 443:443 --privileged rancher/rancher
        end_message




        #firewallのポート許可
        echo "http(80番)とhttps(443番)の許可をしてます"
        start_message
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
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
        http://IPアドレス/
        https://IPアドレス/
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
