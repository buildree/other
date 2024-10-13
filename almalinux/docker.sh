#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT

注意点：conohaのポートは全て許可前提となります。もしくは80番、443番の許可をしておいてください。システムのfirewallはオン状態となります。centosユーザーのパスワードはランダム生成となります。最後に表示されます

目的：Dockerのインストール
・Docker

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

USER_NAME="user"

#RedHat軽か確認
if [ -e /etc/redhat-release ]; then
    DIST="redhat"
    DIST_VER=`cat /etc/redhat-release | sed -e "s/.*\s\([0-9]\)\..*/\1/"`



    if [ $DIST = "redhat" ];then
      if [ $DIST_VER = "8" ] || [ $DIST_VER = "9" ];then

      #SELinuxの確認
SElinux=`which getenforce`
if [ "`${SElinux}`" = "Disabled" ]; then
  echo "SElinuxは無効なのでそのまま続けていきます"
else
  echo "SElinux有効のため、一時的に無効化します"
  setenforce 0

  getenforce
  #exit 1
fi

        #リポジトリのインストール
        start_message
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf install -y wget
        dnf install -y git
        end_message

        #アップデート
        start_message
        echo "dnf updateを実行します"
        dnf -y update --nobest
        end_message

        #インストール
        start_message
        echo 'Dockerをインストールします'
        echo dnf install docker-ce -y
        dnf install docker-ce -y  --allowerasing
        end_message

        #docker composeインストール
        start_message
        echo 'sudo wget -O /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/1.29.0/docker-compose-Linux-x86_64'
        wget -O /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/v2.9.0/docker-compose-Linux-x86_64
        chmod +x /usr/local/bin/docker-compose
        ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        echo 'バージョン確認'
        docker-compose version
        end_message



        #ユーザー作成
        start_message
        echo "ユーザーを作成します"
        USERNAME='user'
        useradd -m  "${USERNAME}"
        PASSWORD=$(more /dev/urandom  | tr -d -c '[:alnum:]' | fold -w 10 | head -1)

        echo "${PASSWORD}" | passwd --stdin "${USER_NAME}"
        echo "パスワードは"${PASSWORD}"です。"

        #作成したユーザーをDockerグループに追加
        usermod -aG docker user

        #起動
        start_message
        echo 'systemctl enable docker'
        systemctl enable docker
        echo '自動起動'
        echo 'systemctl start docker'
         systemctl start docker


        umask 0002


        echo "userのパスワードは"${PASSWORD}"です。"

      else
        echo "CentOS7ではないため、このスクリプトは使えません。このスクリプトのインストール対象はCentOS8系です。"
      fi
    fi

else
  echo "このスクリプトのインストール対象はCentOS8系です。CentOS8系以外は動きません。"
  cat <<EOF
  検証LinuxディストリビューションはDebian・Ubuntu・Fedora・Arch Linux（アーチ・リナックス）となります。
EOF
fi


exec $SHELL -l
