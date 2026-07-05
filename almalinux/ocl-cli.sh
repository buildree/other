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

    # gitのインストール
    sudo dnf -y install git

    # ユーザーを作成
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
    end_message "unicornユーザーの作成"

    # 必要な物をインストール
    start_message "開発ツール・依存パッケージのインストール"
    dnf groupinstall -y "Development Tools"
    dnf install -y gcc wget openssl-devel bzip2-devel libffi-devel
    end_message "開発ツール・依存パッケージのインストール"

    # システムアップデート
    start_message "システムアップデート"
    echo "システムを最新版に更新します"
    dnf -y update
    end_message "システムアップデート"

    start_message "Python 3.12のインストール"
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
    end_message "Python 3.12のインストール"

    start_message "pipのアップグレード"
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
    end_message "pipのアップグレード"

    start_message "OCI CLIのインストール"
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
    end_message "OCI CLIのインストール"

    # 完了サマリーの作成・表示・保存
    build_summary() {
      cat <<SUMMARYEOF
Buildree インストールサマリー - $(date '+%Y-%m-%d %H:%M:%S')

======================実行内容サマリー======================
${EXECUTED_STEPS}
======================作成・変更したファイル======================
- /home/unicorn 以下のユーザーホームディレクトリ一式
- /home/unicorn/.ssh/unicorn.pub (SSH公開鍵)
- /home/unicorn/.ssh/authorized_keys
- /home/unicorn/unicorn (SSH秘密鍵)
- /etc/profile.d/python.sh (PATHにpython/pipを追加)
- /home/unicorn/oracle-cli (OCI CLI用Python仮想環境)
- /home/unicorn/.bashrc (oci-activateエイリアスを追記)

======================unicornユーザーの認証情報======================
- ログイン方式: SSH鍵認証(ed25519)
- 秘密鍵: /home/unicorn/unicorn (パーミッション600)
- 公開鍵: /home/unicorn/.ssh/unicorn.pub
- OSログインパスワードはランダム生成後、画面表示・ファイル保存はしていません(セキュリティのため)。必要な場合は passwd unicorn で再設定してください。

======================警告======================
$( [ -n "$WARNINGS" ] && printf '%s' "$WARNINGS" || echo "警告はありませんでした" )

======================アクセス方法・注意事項======================
OCI CLIの使用方法：
1. unicornユーザーでログイン: su - unicorn
2. 仮想環境を有効化: oci-activate または source oracle-cli/bin/activate
3. 仮想環境を無効化: deactivate
4. OCI CLIを使用: oci <コマンド>
例 oci --version にてバージョン表示
SUMMARYEOF
    }

    SUMMARY_TEXT=$(build_summary)
    echo "$SUMMARY_TEXT"
    echo "$SUMMARY_TEXT" > /home/unicorn/buildree_install_summary.txt
    chown unicorn:unicorn /home/unicorn/buildree_install_summary.txt
    chmod 600 /home/unicorn/buildree_install_summary.txt
    echo ""
    echo "このサマリーは /home/unicorn/buildree_install_summary.txt に保存されました。"

    sudo su -l unicorn

  else
    warn_message "対象OSではないため、このスクリプトは使えません。"
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
