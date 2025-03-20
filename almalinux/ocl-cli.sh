#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
作成者：サイトラボ
URL：https://www.site-lab.jp/
URL：https://buildree.com/

注意点：
  - このスクリプトは、AlmaLinux または Rocky Linux をインストールした直後のVPSやクラウドサーバーでの使用を想定しています。
  - 既存の環境で実行した場合、既存の設定やアプリケーションに影響を与える可能性があります。
  - 既存環境での実行は推奨されません。
  - 実行前に必ずバックアップを取得してください。
  - ConoHa のポートは全て許可前提となります。もしくは80番、443番の許可をしておいてください。
  - システムのfirewallはオン状態となります。
  - unicornユーザーのパスワードはランダム生成となります。最後に表示されます。

目的：OCI CLIのインストール
・OCI CLI

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

        #gitなど必要な物をインストール
        start_message
        dnf  groupinstall -y "Development Tools"
        dnf install -y gcc wget openssl-devel bzip2-devel libffi-devel


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
 #!/bin/bash

# 仮想環境のインストール
echo "仮想環境のインストール"
if [ ! -d "oracle-cli" ]; then
  python -m venv oracle-cli
  if [ $? -ne 0 ]; then
    echo "仮想環境の作成に失敗しました。"
    exit 1
  fi
else
  echo "仮想環境はすでに存在します。"
fi

# 仮想環境をアクティブ化
echo "仮想環境をアクティブ化"
source oracle-cli/bin/activate
if [ $? -ne 0 ]; then
  echo "仮想環境のアクティブ化に失敗しました。"
  exit 1
fi

# コマンドライン・インタフェースのインストール
echo "コマンドライン・インタフェースのインストール"
pip install oci-cli
if [ $? -ne 0 ]; then
  echo "OCI CLI のインストールに失敗しました。"
  exit 1
fi

# バージョン確認
echo "バージョン確認"
oci --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
if [ $? -ne 0 ]; then
  echo "OCI CLI のバージョン確認に失敗しました。"
  exit 1
fi

# 仮想環境から抜ける
echo "仮想環境から抜ける"
deactivate
if [ $? -ne 0 ]; then
  echo "仮想環境からの非アクティブ化に失敗しました。"
  exit 1
fi

echo "OCI CLI のインストールおよび設定が完了しました。"
        end_message


        #ユーザー作成
        start_message
        echo "unicornユーザーを作成します"
        USERNAME='unicorn'
        PASSWORD=$(more /dev/urandom | tr -d -c '[:alnum:]' | fold -w 10 | head -1)

        # パスワードをファイルに保存
        echo "${USERNAME}:${PASSWORD}" > /root/unicorn_password.txt
        echo "${USERNAME}:${PASSWORD}" > /home/${USERNAME}/unicorn_password.txt

        # パスワードをユーザーに通知
        echo "unicornユーザーのパスワードは /root/unicorn_password.txt と /home/unicorn/unicorn_password.txt に保存しました。"

        umask 0002

        end_message
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
