#!/bin/bash

# 注意書き
cat <<EOF
注意点：
  - このスクリプトは、AlmaLinux または Rocky Linux をインストールした直後のVPSやクラウドサーバーでの使用を想定しています。
  - 既存の環境で実行した場合、既存の設定やアプリケーションに影響を与える可能性があります。
  - 既存環境での実行は推奨されません。
  - rootユーザーで実行する場合は、コマンド実行に十分注意してください。
  - 実行前に必ずバックアップを取得してください。
  - unicornユーザーのパスワードはランダム生成となります。画面に表示もパスワード保存もされません。新しく設定してください
  - Pythonは3.12を利用してます

目的：
・OCI CLIのインストール
・Python3.12のインストール
・pipのインストール

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

  hash_file="/tmp/hashes.txt"
  expected_sha3_512="e8243148d093f686fb29d2a612a01f9189796f0d9ed07b485da6872709aa7f2449e9d866fbb8026a19f118e44c5a14a3546c15de4fc7cb4de001af607a09cb3f"

  # リポジトリのシェルファイルの格納場所
  update_file_path="/tmp/update.sh"
  useradd_file_path="/tmp/useradd.sh"


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
    echo "サポートされていないディストリビューションです"
    exit 1
  fi

  echo "検出されたディストリビューション: $DIST_NAME $DIST_VERSION_ID"

  # Redhat系で8または9の場合のみ処理を実行
  if [ -e /etc/redhat-release ] && [[ "$DIST_MAJOR_VERSION" -eq 8 || "$DIST_MAJOR_VERSION" -eq 9 ]]; then

    # ハッシュファイルのダウンロード
    start_message
    if ! curl --tlsv1.3 --proto https -o "$hash_file" https://raw.githubusercontent.com/buildree/common/main/other/hashes.txt; then
      echo "エラー: ファイルのダウンロードに失敗しました"
      exit 1
    fi

    # ファイルのSHA3-512ハッシュ値を計算
    actual_sha3_512=$(sha3sum -a 512 "$hash_file" 2>/dev/null | awk '{print $1}')
    # sha3sumコマンドが存在しない場合の代替手段
    if [ -z "$actual_sha3_512" ]; then
      actual_sha3_512=$(openssl dgst -sha3-512 "$hash_file" 2>/dev/null | awk '{print $2}')

      if [ -z "$actual_sha3_512" ]; then
        echo "エラー: SHA3-512ハッシュの計算に失敗しました。sha3sumまたはOpenSSLがインストールされていることを確認してください。"
        rm -f "$hash_file"
        exit 1
      fi
    fi

    # ハッシュ値を比較
    if [ "$actual_sha3_512" == "$expected_sha3_512" ]; then
      echo "ハッシュ値は一致します。ファイルを保存します。"
      
      # ハッシュ値ファイルの読み込み - ダウンロード成功後に行う
      repository_hash=$(grep "^repository_hash_sha512=" "$hash_file" | cut -d '=' -f 2)
      update_hash=$(grep "^update_hash_sha512=" "$hash_file" | cut -d '=' -f 2)
      repository_hash_sha3=$(grep "^repository_hash_sha3_512=" "$hash_file" | cut -d '=' -f 2)
      update_hash_sha3=$(grep "^update_hash_sha3_512=" "$hash_file" | cut -d '=' -f 2)
      useradd_hash=$(grep "^useradd_hash_sha512=" "$hash_file" | cut -d '=' -f 2)
      useradd_hash_sha3=$(grep "^useradd_hash_sha3_512=" "$hash_file" | cut -d '=' -f 2)
    else
      echo "ハッシュ値が一致しません。ファイルを削除します。"
      echo "期待されるSHA3-512: $expected_sha3_512"
      echo "実際のSHA3-512: $actual_sha3_512"
      rm -f "$hash_file"
      exit 1
    fi
    end_message

    # gitのインストール
    sudo dnf -y install git

    # ユーザー作成スクリプトをダウンロード
    if ! curl --tlsv1.3 --proto https -o "$useradd_file_path" https://raw.githubusercontent.com/buildree/common/main/user/useradd.sh; then
      echo "エラー: ファイルのダウンロードに失敗しました"
      exit 1
    fi

    # ファイルの存在を確認
    if [ ! -f "$useradd_file_path" ]; then
      echo "エラー: ダウンロードしたファイルが見つかりません: $useradd_file_path"
      exit 1
    fi

    # ファイルのSHA512ハッシュ値を計算
    actual_sha512=$(sha512sum "$useradd_file_path" 2>/dev/null | awk '{print $1}')
    if [ -z "$actual_sha512" ]; then
      echo "エラー: SHA512ハッシュの計算に失敗しました"
      exit 1
    fi

    # ファイルのSHA3-512ハッシュ値を計算
    actual_sha3_512=$(sha3sum -a 512 "$useradd_file_path" 2>/dev/null | awk '{print $1}')

    # システムにsha3sumがない場合の代替手段
    if [ -z "$actual_sha3_512" ]; then
      # OpenSSLを使用する方法
      actual_sha3_512=$(openssl dgst -sha3-512 "$useradd_file_path" 2>/dev/null | awk '{print $2}')
      
      # それでも取得できない場合はエラー
      if [ -z "$actual_sha3_512" ]; then
        echo "エラー: SHA3-512ハッシュの計算に失敗しました。sha3sumまたはOpenSSLがインストールされていることを確認してください"
        exit 1
      fi
    fi

    # 両方のハッシュ値が一致した場合のみ処理を続行
    if [ "$actual_sha512" == "$useradd_hash" ] && [ "$actual_sha3_512" == "$useradd_hash_sha3" ]; then
      echo "ハッシュ検証が成功しました。ユーザー作成を続行します。"
      
      # 実行権限を付与
      chmod +x "$useradd_file_path"
      
      # スクリプトを実行
      source "$useradd_file_path"
      
      # 実行後に削除
      rm -f "$useradd_file_path"
    else
      echo "エラー: ハッシュ検証に失敗しました。"
      echo "期待されるSHA512: $useradd_hash"
      echo "実際のSHA512: $actual_sha512"
      echo "期待されるSHA3-512: $useradd_hash_sha3"
      echo "実際のSHA3-512: $actual_sha3_512"
      
      # セキュリティリスクを軽減するため、検証に失敗したファイルを削除
      rm -f "$useradd_file_path"
      exit 1
    fi
    end_message

    # 必要な物をインストール
    start_message
    dnf groupinstall -y "Development Tools"
    dnf install -y gcc wget openssl-devel bzip2-devel libffi-devel
    end_message

    # dnf updateを実行
    start_message
    echo "dnf updateを実行します"
    echo ""
    
    # dnf updateを実行
    start_message
    echo "システムをアップデートします"
    # アップデートスクリプトをGitHubから/tmpにダウンロードして実行
    if ! curl --tlsv1.3 --proto https -o "$update_file_path" https://raw.githubusercontent.com/buildree/common/main/system/update.sh; then
      echo "エラー: ファイルのダウンロードに失敗しました"
      exit 1
    fi

    # ファイルの存在を確認
    if [ ! -f "$update_file_path" ]; then
      echo "エラー: ダウンロードしたファイルが見つかりません: $update_file_path"
      exit 1
    fi

    # ファイルのSHA512ハッシュ値を計算
    actual_sha512=$(sha512sum "$update_file_path" 2>/dev/null | awk '{print $1}')
    if [ -z "$actual_sha512" ]; then
      echo "エラー: SHA512ハッシュの計算に失敗しました"
      exit 1
    fi

    # ファイルのSHA3-512ハッシュ値を計算
    actual_sha3_512=$(sha3sum -a 512 "$update_file_path" 2>/dev/null | awk '{print $1}')

    # システムにsha3sumがない場合の代替手段
    if [ -z "$actual_sha3_512" ]; then
      # OpenSSLを使用する方法
      actual_sha3_512=$(openssl dgst -sha3-512 "$update_file_path" 2>/dev/null | awk '{print $2}')
      
      # それでも取得できない場合はエラー
      if [ -z "$actual_sha3_512" ]; then
        echo "エラー: SHA3-512ハッシュの計算に失敗しました。sha3sumまたはOpenSSLがインストールされていることを確認してください"
        exit 1
      fi
    fi

    # 両方のハッシュ値が一致した場合のみ処理を続行
    if [ "$actual_sha512" == "$update_hash" ] && [ "$actual_sha3_512" == "$update_hash_sha3" ]; then
      echo "両方のハッシュ値が一致します。"
      echo "このスクリプトは安全のためインストール作業を実施します"
      
      # 実行権限を付与
      chmod +x "$update_file_path"
      
      # スクリプトを実行
      source "$update_file_path"
      
      # 実行後に削除
      rm -f "$update_file_path"
    else
      echo "ハッシュ値が一致しません！"
      echo "期待されるSHA512: $update_hash"
      echo "実際のSHA512: $actual_sha512"
      echo "期待されるSHA3-512: $update_hash_sha3"
      echo "実際のSHA3-512: $actual_sha3_512"
      
      # セキュリティリスクを軽減するため、検証に失敗したファイルを削除
      rm -f "$update_file_path"
      exit 1 #一致しない場合は終了
    fi
    end_message

    start_message
    echo "pythonのインストールをします"
    dnf install -y python3.12 python3.12-devel python3.12-pip
    echo "起動時に読み込まれるようにします"
    
    # /usr/local/binをPATHに追加
    if ! grep -q "/usr/local/bin" /etc/profile.d/python.sh 2>/dev/null; then
      cat >/etc/profile.d/python.sh <<'EOF'
export PATH="/usr/local/bin:/usr/bin:$PATH"
EOF
    fi
    
    source /etc/profile.d/python.sh
    sudo ln -sf /usr/bin/python3 /usr/bin/python
    sudo ln -s /usr/bin/pip3.12 /usr/bin/pip
    end_message

    start_message
    echo "pipのアップグレードをします"
    # システム全体のpipをアップグレード
    python3.12 -m pip install --upgrade pip
    
    # パスを確認
    echo "PATHを確認:"
    echo $PATH
    
    # pipの場所とバージョンを確認
    echo "pipの場所:"
    which pip
    echo "pipのバージョン:"
    pip --version
    end_message

    start_message
    echo "OCI CLIのインストール処理を開始します"

    # 仮想環境用のスクリプトを作成
    cat > /tmp/install_oci_cli.sh << 'EOF'
#!/bin/bash
# 仮想環境のインストール
echo "仮想環境のインストール"
if [ ! -d "$HOME/oracle-cli" ]; then
  python -m venv $HOME/oracle-cli
  if [ $? -ne 0 ]; then
    echo "仮想環境の作成に失敗しました。"
    exit 1
  fi
else
  echo "仮想環境はすでに存在します。"
fi

# 仮想環境をアクティブ化
echo "仮想環境をアクティブ化"
source $HOME/oracle-cli/bin/activate
if [ $? -ne 0 ]; then
  echo "仮想環境のアクティブ化に失敗しました。"
  exit 1
fi

# 仮想環境内のpipをアップグレード
echo "仮想環境内のpipをアップグレード"
pip install --upgrade pip
if [ $? -ne 0 ]; then
  echo "仮想環境内のpipのアップグレードに失敗しました。"
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

# .bashrcに仮想環境の設定を追加
if ! grep -q "oracle-cli/bin/activate" "$HOME/.bashrc"; then
  echo -e "\n# Oracle CLI 仮想環境のアクティベーション" >> "$HOME/.bashrc"
  echo "alias oci-activate='source $HOME/oracle-cli/bin/activate'" >> "$HOME/.bashrc"
  echo "# ログイン時に自動的に仮想環境をアクティブ化したい場合は、次の行のコメントを解除してください" >> "$HOME/.bashrc"
  echo "# source $HOME/oracle-cli/bin/activate" >> "$HOME/.bashrc"
fi

# 明示的に成功を示すファイルを作成
touch /tmp/oci_cli_install_success
EOF

    # 実行権限を付与
    chmod +x /tmp/install_oci_cli.sh
    # unicornユーザー所有にする
    chown unicorn:unicorn /tmp/install_oci_cli.sh

    # unicornユーザーとして実行する（サブシェルで実行せず、直接コマンドを実行）
    sudo -u unicorn bash /tmp/install_oci_cli.sh

    # インストール成功の確認
    if [ -f /tmp/oci_cli_install_success ]; then
      echo "OCI CLI のインストールおよび設定が完了しました。"
      rm /tmp/oci_cli_install_success
    else
      echo "OCI CLI のインストールに問題が発生しました。"
      exit 1
    fi

    # 一時ファイルの削除
    rm -f /tmp/install_oci_cli.sh

    # ユーザーの切り替え
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
    
    # OCI CLI使用方法の説明を追加
    echo ""
    echo "OCI CLIの使用方法："
    echo "1. unicornユーザーでログイン: su - unicorn"
    echo "2. 仮想環境を有効化: oci-activate または source oracle-cli/bin/activate"
    echo "3. 仮想環境を無効化: deactivate"
    echo "4. OCI CLIを使用: oci <コマンド>"
    echo "例 oci --version にてバージョン表示"
    sudo su -l unicorn

  else
    echo "対象OSではないため、このスクリプトは使えません。"
  fi
elif [ "$choice" = "n" ]; then
  # スクリプトの実行を中止
  echo "スクリプトの実行を中止しました。"
  exit 0
else
  # 無効な入力
  echo "無効な入力です。y または n を入力してください。"
  exit 1
fi