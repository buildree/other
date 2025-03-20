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

#RedHat系か確認
if [ -e /etc/redhat-release ]; then
    DIST="redhat"
    DIST_VER=`cat /etc/redhat-release | sed -e "s/.*\s\([0-9]\)\..*/\1/"`

    if [ $DIST = "redhat" ];then
      if [ $DIST_VER = "8" ] || [ $DIST_VER = "9" ];then
        #EPELリポジトリのインストール
        start_message
        #Keyの更新
        rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
        dnf remove -y epel-release
        dnf -y install epel-release
        end_message

        #gitなど必要な物をインストール
        start_message
        dnf  groupinstall -y "Development Tools"
        dnf install -y gcc gcc-c++ make git  zlib-devel readline-devel sqlite-devel bzip2-devel libffi-devel perl perl-Test-Simple perl-Test-Harness openssl-devel wget


        # dnf updateを実行
        start_message
        echo "dnf updateを実行します"
        echo ""
        curl -OL https://buildree.com/download/common/system/update.sh -o update.sh
        source ./update.sh
        end_message

        start_message
        echo "pythonのインストールをします"
        dnf install -y python3.12 python3.12-devel python3.12-pip
        echo "起動時に読み込まれるようにします"
cat >/etc/profile.d/python.sh <<'EOF'
export PATH="/usr/bin:$PATH" #python3.12のパス
export PATH="/usr/bin:$PATH" #pipのインストールパス
EOF
        source /etc/profile.d/python.sh
        sudo ln -sf /usr/bin/python3 /usr/bin/python
        sudo ln -s /usr/bin/pip3.12 /usr/bin/pip
        end_message

        start_message
        echo "pipのアップグレードをします"
        pip install --upgrade pip
        end_message

        start_message
        echo "仮想環境のインストール"
        echo "python -m venv oracle-cli"
        python -m venv oracle-cli
        echo "仮想環境をアクティブ化"
        echo "source oracle-cli/bin/activate"
        source oracle-cli/bin/activate
        end_message

        start_message
        echo "コマンドライン・インタフェースのインストール"
        echo "pip install oci-cli"
        pip install oci-cli
        echo "バージョン確認"
        oci --version
        end_message

        start_message
        echo "仮想環境から抜ける"
        echo "deactivate"
        deactivate
        end_message


        #ユーザー作成
        start_message
        echo "unicornユーザーを作成します"
        USERNAME='unicorn'
        PASSWORD=$(more /dev/urandom  | tr -d -c '[:alnum:]' | fold -w 10 | head -1)

        echo "${PASSWORD}" | passwd --stdin "${USERNAME}"
        echo "パスワードは"${PASSWORD}"です。"

        umask 0002

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
