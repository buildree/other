#!/bin/bash

# Buildree Apache + Angularインストールスクリプト
# 目的：Apache 2.4系のインストール、Node.js 20のインストール、Angular CLIのインストール、SSL設定の構成、gzip圧縮の有効化、htaccess許可設定、unicornユーザーの自動作成
# 対象：AlmaLinux、Rocky Linux、RHEL、CentOS Stream、Oracle Linux (8/9系)

# 起動メッセージと確認
cat <<EOF
-----------------------------------------------------
Buildree Apache + Angularインストールスクリプト
-----------------------------------------------------
注意点：
  - AlmaLinux、Rocky Linux、RHEL、CentOS Stream、Oracle Linux専用
  - rootユーザーまたはsudo権限が必要
  - 新規環境での使用を推奨
  - 実行前にバックアップを推奨

目的：
  - Apache 2.4系のインストール
  - Node.js 20のインストール
  - Angular CLIのインストール
  - SSL設定の構成
  - gzip圧縮の有効化
  - htaccess許可設定
  - unicornユーザーの自動作成

ドキュメントルート: /var/www/html
EOF

read -p "インストールを続行しますか？ (y/n): " choice
[ "$choice" != "y" ] && { echo "インストールを中止しました。"; exit 0; }

# プロジェクト名の設定
read -p "Angularプロジェクト名を入力してください (デフォルト: buildree-app): " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-buildree-app}
echo "プロジェクト名: $PROJECT_NAME"

# ディストリビューションとバージョンの検出
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DIST_ID=$ID
    DIST_VERSION_ID=$VERSION_ID
    DIST_NAME=$NAME
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

# 処理開始・終了メッセージ関数（修正版）
start_message(){
    echo ""
    echo "====================== 開始: $1 ======================"
    echo ""
}

end_message(){
    echo ""
    echo "====================== 完了: $1 ======================"
    echo ""
}

# ユーザーがrootかどうかチェック
if [ "$(id -u)" != "0" ]; then
    echo "このスクリプトはroot権限で実行する必要があります。"
    exit 1
fi

# RHEL系8/9のみ処理
if [ -e /etc/redhat-release ]; then
    if [ "$DIST_MAJOR_VERSION" = "8" ] || [ "$DIST_MAJOR_VERSION" = "9" ]; then
        # システム関連のインストールと設定を実行するスクリプト部分

        # Gitリポジトリのインストール
        start_message "Gitリポジトリのインストール"
        echo "Gitをインストールしています..."
        dnf -y install git
        end_message "Gitリポジトリのインストール"

        # システムアップデート
        start_message "システムアップデート"
        echo "システムアップデートスクリプトを取得しています..."
        curl --tlsv1.3 --proto https -o /tmp/update.sh https://raw.githubusercontent.com/buildree/common/main/system/update.sh
        chmod +x /tmp/update.sh
        echo "システムアップデートを実行中..."
        source /tmp/update.sh
        rm -f /tmp/update.sh
        end_message "システムアップデート"

        # SELinuxにHTTPの許可
        start_message "SELinux設定"
        echo "SELinuxにHTTPの許可をしています..."
        echo "実行コマンド: setsebool -P httpd_can_network_connect 1"
        setsebool -P httpd_can_network_connect 1
        end_message "SELinux設定"

        # Node.jsのインストール
        start_message "Node.jsインストール"
        echo "インストール可能なNode.jsモジュールを確認しています..."
        dnf module list nodejs
        echo "Node.js 20モジュールを有効化しています..."
        
        # Node.js 20の有効化とインストール
        if ! dnf module -y enable nodejs:20; then
            echo "Node.jsモジュールの有効化に失敗しました"
            exit 1
        fi
        
        echo "Node.js 20をインストールしています..."
        if ! dnf module install -y nodejs:20; then
            echo "Node.jsのインストールに失敗しました"
            exit 1
        fi
        
        echo "インストールされたNode.jsのバージョンを確認しています..."
        node -v
        echo "インストールされたnpmのバージョンを確認しています..."
        npm -v
        end_message "Node.jsインストール"

        # npmの更新
        start_message "npmの更新"
        echo "npmを最新の安定版にアップデートしています..."
        npm install -g npm@latest
        echo "更新後のnpmバージョン:"
        npm -v
        end_message "npmの更新"

        # Apacheのインストール
        start_message "Apacheインストール"
        echo "Apache HTTPサーバーとSSLモジュールをインストールしています..."
        dnf install -y httpd mod_ssl
        echo "インストールされたApacheのバージョン:"
        httpd -v
        end_message "Apacheインストール"

        # Apacheの設定変更
        start_message "Apache設定"
        echo "Apacheの設定を変更します..."
        echo "ドキュメントルートでhtaccessを有効化しています..."
        echo "実行コマンド: sed -i -e \"151d\" /etc/httpd/conf/httpd.conf"
        echo "実行コマンド: sed -i -e \"151i AllowOverride All\" /etc/httpd/conf/httpd.conf"
        sed -i -e "151d" /etc/httpd/conf/httpd.conf
        sed -i -e "151i AllowOverride All" /etc/httpd/conf/httpd.conf
        
        echo "セキュリティ強化のためサーバーバージョン情報を隠しています..."
        echo "実行コマンド: sed -i -e \"350i #バージョン非表示\" /etc/httpd/conf/httpd.conf"
        echo "実行コマンド: sed -i -e \"351i ServerTokens ProductOnly\" /etc/httpd/conf/httpd.conf"
        echo "実行コマンド: sed -i -e \"352i ServerSignature off \n\" /etc/httpd/conf/httpd.conf"
        sed -i -e "350i #バージョン非表示" /etc/httpd/conf/httpd.conf
        sed -i -e "351i ServerTokens ProductOnly" /etc/httpd/conf/httpd.conf
        sed -i -e "352i ServerSignature off \n" /etc/httpd/conf/httpd.conf
        end_message "Apache設定"

        # gzip圧縮の設定
        start_message "gzip圧縮設定"
        echo "Webコンテンツのgzip圧縮を有効化しています..."
        echo "gzip設定ファイルを作成: /etc/httpd/conf.d/gzip.conf"
        cat >/etc/httpd/conf.d/gzip.conf <<'EOF'
SetOutputFilter DEFLATE
BrowserMatch ^Mozilla/4 gzip-only-text/html
BrowserMatch ^Mozilla/4\.0[678] no-gzip
BrowserMatch \bMSI[E] !no-gzip !gzip-only-text/html
SetEnvIfNoCase Request_URI\.(?:gif|jpe?g|png)$ no-gzip dont-vary
Header append Vary User-Agent env=!dont-var
EOF
        echo "gzip圧縮設定を完了しました"
        end_message "gzip圧縮設定"

        # unicornユーザー作成（ランダムパスワード生成方式に戻す）
        start_message "unicornユーザー作成"
        echo "unicornユーザーを作成しています..."
        # unicornユーザーを作成
        useradd -m -s /bin/bash unicorn
        # ランダムなパスワードを生成
        PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)
        echo "一時的なランダムパスワードを設定しています（インストール完了後に変更してください）..."
        echo "$PASSWORD" | passwd --stdin unicorn
        # ユーザーをapacheグループに追加
        echo "unicornユーザーをapacheグループに追加しています..."
        usermod -aG apache unicorn
        end_message "unicornユーザー作成"

        # Angular CLIのインストール（rootとして）
        start_message "Angular CLIのグローバルインストール"
        echo "Angular CLIをグローバルにインストールしています..."
        npm install -g @angular/cli
        echo "Angular CLIを最新バージョンに更新しています..."
        npm install -g @angular/cli@latest
        echo "インストールされたAngular CLIのバージョン:"
        ng version
        end_message "Angular CLIのグローバルインストール"

        # プロジェクトディレクトリの作成と権限設定
        start_message "プロジェクトディレクトリの準備"
        echo "プロジェクトディレクトリを作成しています: /var/www/${PROJECT_NAME}"
        mkdir -p /var/www/${PROJECT_NAME}
        echo "ディレクトリの所有者をunicorn:apacheに設定しています..."
        chown -R unicorn:apache /var/www/${PROJECT_NAME}
        echo "ディレクトリに適切な権限を設定しています: 775"
        chmod -R 775 /var/www/${PROJECT_NAME}
        end_message "プロジェクトディレクトリの準備"

        # ドキュメントルートの準備
        start_message "ドキュメントルートの準備"
        echo "ドキュメントルートディレクトリを作成しています: /var/www/html"
        mkdir -p /var/www/html
        echo "ドキュメントルートの所有者をunicorn:apacheに設定しています..."
        chown -R unicorn:apache /var/www/html
        echo "ドキュメントルートに適切な権限を設定しています: 775"
        chmod -R 775 /var/www/html
        end_message "ドキュメントルートの準備"

cat >/home/unicorn/setup_angular.sh <<EOF
#!/bin/bash
# このスクリプトはunicornユーザーとして実行されます

PROJECT_NAME="${PROJECT_NAME}"
cd /var/www/\${PROJECT_NAME}

# 自動応答のためのフラグ設定
export NG_FORCE_TTY=false
export NG_ANALYTICS=true

# Angularプロジェクトを作成（自動応答オプション付き）
echo "Angularプロジェクトを作成中..."
ng new \${PROJECT_NAME} --skip-git --defaults --skip-tests --style=css --routing=true

if [ \$? -ne 0 ]; then
    echo "Angularプロジェクトの作成に失敗しました"
    exit 1
fi

cd /var/www/\${PROJECT_NAME}/\${PROJECT_NAME}

# アプリケーションのビルド
echo "Angularアプリケーションをビルド中..."
ng build --configuration production

if [ \$? -ne 0 ]; then
    echo "Angularアプリケーションのビルドに失敗しました"
    exit 1
fi

# ビルド結果を確認
echo "ビルド結果ディレクトリの構造:"
ls -la
if [ -d "dist" ]; then
    echo "distディレクトリの内容:"
    ls -la dist/
else
    echo "警告: distディレクトリが見つかりません"
    # 代替の場所を探す
    DIST_DIR=\$(find . -type d -name "dist" | head -1)
    if [ -n "\$DIST_DIR" ]; then
        echo "代替のdistディレクトリが見つかりました: \$DIST_DIR"
        echo "\$DIST_DIRの内容:"
        ls -la "\$DIST_DIR"
    else
        echo "distディレクトリが見つかりません。ビルドに問題がある可能性があります。"
        exit 1
    fi
fi

# browser ディレクトリがdistに含まれている場合
if [ -d "dist/browser" ]; then
    echo "新しいAngular出力形式(dist/browser/)を検出しました"
    echo "ドキュメントルートにdist/browser/の内容をコピーします"
    rm -rf /var/www/html/*
    cp -rp dist/browser/* /var/www/html/
elif [ -d "dist/\${PROJECT_NAME}" ]; then
    echo "標準的なAngular出力形式(dist/プロジェクト名/)を検出しました"
    echo "ドキュメントルートにdist/\${PROJECT_NAME}/の内容をコピーします"
    rm -rf /var/www/html/*
    cp -rp dist/\${PROJECT_NAME}/browser/* /var/www/html/
else
    echo "直接distディレクトリの内容をコピーします"
    rm -rf /var/www/html/*
    cp -rp dist/* /var/www/html/
fi

echo "ドキュメントルートの内容:"
ls -la /var/www/html/

echo "Angularセットアップ完了"
EOF

        # スクリプトの権限設定
        echo "Angular初期設定スクリプトの権限を設定しています..."
        chmod 755 /home/unicorn/setup_angular.sh
        chown unicorn:unicorn /home/unicorn/setup_angular.sh

        # unicornユーザーとしてAngularプロジェクト作成スクリプトを実行
        start_message "unicornユーザーとしてAngularプロジェクトを作成"
        echo "unicornユーザーとしてAngularプロジェクト作成スクリプトを実行しています..."
        su - unicorn -c "/home/unicorn/setup_angular.sh"
        
        if [ $? -ne 0 ]; then
            echo "Angularプロジェクトの作成に失敗しました"
            exit 1
        fi
        end_message "unicornユーザーとしてAngularプロジェクトを作成"

        # 所属グループ表示
        start_message "所属グループ確認"
        echo "apacheグループのメンバーシップを表示します:"
        getent group apache
        end_message "所属グループ確認"

        # Apacheサービス設定
        start_message "Apacheサービス設定"
        echo "Apache HTTPサービスを開始しています..."
        systemctl start httpd.service
        echo "Apache HTTPサービスを自動起動に設定しています..."
        systemctl enable httpd
        echo "Apacheサービスの状態を確認しています:"
        systemctl list-unit-files --type=service | grep httpd
        end_message "Apacheサービス設定"

        # ファイアウォール設定
        start_message "ファイアウォール設定"
        echo "HTTPポート(80)を開放しています..."
        firewall-cmd --permanent --add-service=http
        echo "HTTPSポート(443)を開放しています..."
        firewall-cmd --permanent --add-service=https
        echo "ファイアウォール設定を更新しています..."
        firewall-cmd --reload
        echo "現在のファイアウォール設定を表示します:"
        firewall-cmd --list-all
        end_message "ファイアウォール設定"

        # 権限設定
        start_message "権限設定"
        echo "デフォルトのumaskを0002に設定しています..."
        umask 0002
        end_message "権限設定"

        # Angular SPA用のサンプル.htaccessファイルを作成
        start_message "Angular SPA用の.htaccessファイル作成"
        echo "Angular SPA用の.htaccessファイルを作成しています..."
        cat >/var/www/html/.htaccess <<'EOF'
# Angular SPAのためのhtaccessファイル
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /
  # 既存のファイルやディレクトリでなければSPAファイルにリダイレクト
  RewriteRule ^index\.html$ - [L]
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule . /index.html [L]
</IfModule>
EOF
        chown unicorn:apache /var/www/html/.htaccess
        chmod 644 /var/www/html/.htaccess
        echo ".htaccessファイルが作成されました"
        end_message "Angular SPA用の.htaccessファイル作成"

        # 完了メッセージ
        cat <<EOF
-----------------------------------------------------
インストール完了
-----------------------------------------------------
http://IPアドレス or ドメイン名
https://IPアドレス or ドメイン名
で確認してみてください

設定ファイルは
/etc/httpd/conf.d/ドメイン名.conf
となっています

ドキュメントルート(DR)は
/var/www/html
となります。

Angularプロジェクトのソースコードは
/var/www/${PROJECT_NAME}/${PROJECT_NAME}
に保存されています。

今後の開発で変更を加える場合は、unicornユーザーとして以下のディレクトリで作業し、
ビルド後に以下のコマンドでドキュメントルートに反映させてください：

su - unicorn
cd /var/www/${PROJECT_NAME}/${PROJECT_NAME}
npx @angular/cli build --configuration production
# 新しい形式の場合
cp -r dist/browser/* /var/www/html/
# または従来の形式の場合
cp -r dist/${PROJECT_NAME}/* /var/www/html/

htaccessはドキュメントルートのみ有効化しています。
Angular SPA用のサンプル.htaccessファイルも作成しています。

●HTTP2について
SSLのconfファイルに｢Protocols h2 http/1.1｣と追記してください

例）
<VirtualHost *:443>
    ServerName example.com
    ServerAlias www.example.com

    Protocols h2 http/1.1　←追加
    DocumentRoot /var/www/html


<Directory /var/www/html/>
    AllowOverride All
    Require all granted
</Directory>

</VirtualHost>

ドキュメントルートの所有者：unicorn
グループ：apache
になっているため、ユーザー名とグループの変更が必要な場合は変更してください

※セキュリティ上の注意※
unicornユーザーには一時的なランダムパスワードが設定されています。
セキュリティ確保のため、以下のコマンドでパスワードを再設定してください:

sudo passwd unicorn

また、可能な限りSSH接続には公開鍵認証を使用することを推奨します。
EOF

    else
        echo "このスクリプトはRHEL/CentOS 8または9系のみ対応しています。"
        echo "検出されたバージョン: ${DIST_NAME} ${DIST_VERSION_ID}"
        exit 1
    fi
else
    echo "このスクリプトはRHEL系のみ対応しています。"
    echo "対応ディストリビューション: AlmaLinux、Rocky Linux、RHEL、CentOS Stream、Oracle Linux (8/9系)"
    exit 1
fi

exec $SHELL -l