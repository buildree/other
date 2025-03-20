#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

# 注意書き
cat <<EOF
注意点：
  - このスクリプトは、AlmaLinux または Rocky Linux をインストールした直後のVPSやクラウドサーバーでの使用を想定しています。
  - 既存の環境で実行した場合、既存の設定やアプリケーションに影響を与える可能性があります。
  - 既存環境での実行は推奨されません。
  - rootユーザーで実行する場合は、コマンド実行に十分注意してください。
  - 実行前に必ずバックアップを取得してください。
  - ConoHa のポートは全て許可前提となります。もしくは80番、443番の許可をしておいてください。
  - システムのfirewallはオン状態となります。
  - unicornユーザーのパスワードはランダム生成となります。最後に表示されます。

目的：OCI CLIのインストール
・OCI CLI

実行してもよろしいですか？ (y/n): 
EOF

# ユーザーからの入力を受け取る
read -r choice

# 入力に応じて処理を分岐
if [ "$choice" = "y" ]; then
  # スクリプトの実行

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

        #gitのインストール
        sudo dnf -y install git

        # ユーザーを作成
        start_message
        echo "ユーザー作成をします"
        echo ""
        curl -O https://raw.githubusercontent.com/site-lab/common/main/user/useradd.sh
        source ./useradd.sh
        end_message


        #gitなど必要な物をインストール
        start_message
        dnf groupinstall -y "Development Tools"
        dnf install -y gcc wget openssl-devel bzip2-devel libffi-devel
        end_message

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
echo "OCI CLIのインストール処理を開始します"
sudo su -l unicorn

# 仮想環境用の一時スクリプトを作成
cat > install_oci_cli.sh << 'EOF'
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

# 明示的に成功を示すファイルを作成
touch /tmp/oci_cli_install_success
EOF

# 実行権限を付与
chmod +x install_oci_cli.sh

# 新しいシェルで実行
bash ./install_oci_cli.sh

# インストール成功の確認
if [ -f /tmp/oci_cli_install_success ]; then
  echo "OCI CLI のインストールおよび設定が完了しました。"
  rm /tmp/oci_cli_install_success
else
  echo "OCI CLI のインストールに問題が発生しました。"
  exit 1
fi

        end_message
# 終わりのメッセージをここに残す
        echo "ed25519 SSH鍵が生成されました。"
echo "秘密鍵: /home/${USERNAME}/${USERNAME}"
echo "公開鍵: /home/${USERNAME}/.ssh/${USERNAME}.pub"
echo ""
echo "秘密鍵が /home/${USERNAME}/${USERNAME} に移動されました。"
echo "秘密鍵のパーミッションは 600 に設定されています。"
echo "このファイルを安全な方法でクライアントマシンに移動し、サーバーからは削除することを強く推奨します。"
echo "秘密鍵はサーバー上に保管せず、使用するクライアントマシンにのみ保管してください。"
echo "公開鍵をクライアントマシンの ~/.ssh/authorized_keys ファイルに追加してください。"
echo "必要に応じて、秘密鍵にパスフレーズを設定してください。"
echo "ユーザーのパスワードはランダムで生成されています。セキュリティの関係上表示したりファイルに残していないので新しく設定してください。"

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
elif [ "$choice" = "n" ]; then
  # スクリプトの実行を中止
  echo "スクリプトの実行を中止しました。"
  exit 0
else
  # 無効な入力
  echo "無効な入力です。y または n を入力してください。"
  exit 1
fi