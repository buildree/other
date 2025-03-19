#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
URL：https://buildree.com/

注意点：conohaのポートは全て許可前提となります。もしくは80番、443番の許可をしておいてください。システムのfirewallはオン状態となります。centosユーザーのパスワードはランダム生成となります。最後に表示されます

目的：システム更新+apache2.4系のインストール
・apache2.4系
・mod_sslのインストール
・centosユーザーの作成
・pyenvのインストール
・djangとの連携

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
    #DIST_VER=`cat /etc/redhat-release | perl -pe 's/.*release ([0-9.]+) .*/$1/' | cut -d "." -f 1`

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


        #EPELリポジトリのインストール
        start_message
        dnf remove -y epel-release
        dnf -y install epel-release
        end_message

        #必要なパッケージのインストール
        start_message
        dnf -y install git zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel make gcc python3-devel libffi-devel
        end_message



        # dnf updateを実行
        echo "dnf updateを実行します"
        echo ""

        start_message
        dnf -y update
        end_message

        # apacheのインストール
        echo "apacheをインストールします"
        dnf  install -y httpd mod_ssl httpd-devel

        ls /etc/httpd/conf/
        echo "Apacheのバージョン確認"
        echo ""
        httpd -v
        echo ""
        end_message

        #gzip圧縮の設定
        cat >/etc/httpd/conf.d/gzip.conf <<'EOF'
SetOutputFilter DEFLATE
BrowserMatch ^Mozilla/4 gzip-only-text/html
BrowserMatch ^Mozilla/4\.0[678] no-gzip
BrowserMatch \bMSI[E] !no-gzip !gzip-only-text/html
SetEnvIfNoCase Request_URI\.(?:gif|jpe?g|png)$ no-gzip dont-vary
Header append Vary User-Agent env=!dont-var
EOF

        #モジュールの読み込み
        sed -i -e "353i LoadModule wsgi_module modules/mod_wsgi-py312.cpython-312-x86_64-linux-gnu.so \n" /etc/httpd/conf/httpd.conf
        sed -i -e "354i WSGIScriptAlias / /var/www/html/mysite/wsgi.py \n" /etc/httpd/conf/httpd.conf
        sed -i -e "355i WSGIPythonPath /var/www/html/ \n" /etc/httpd/conf/httpd.conf
        sed -i -e "356i <Directory /var/www/html/mysite> \n" /etc/httpd/conf/httpd.conf
        sed -i -e "357i <Files wsgi.py> \n" /etc/httpd/conf/httpd.conf
        sed -i -e "358i Require all granted \n" /etc/httpd/conf/httpd.conf
        sed -i -e "359i </Files> \n" /etc/httpd/conf/httpd.conf
        sed -i -e "360i </Directory> \n" /etc/httpd/conf/httpd.conf


        #pyenvの設定
        echo "pythonのインストールをします"
        curl -OL https://buildree.com/download/common/system/pyenv.sh
        source ./pyenv.sh

        #mod_wsgiのインストール
        start_message
        echo "mod_wsgiのインストール"
        pip install mod-wsgi
        end_message

        #インストール場所を調べる
        start_message
        echo "インストール場所を調べます"
        pip show mod-wsgi
        ls -all /usr/local/pyenv/versions/3.12.5/lib/python3.12/site-packages/mod_wsgi/server/
        end_message

        #ファイルのコピー
        start_message
        echo "ファイルをコピーします"
        cp  /usr/local/pyenv/versions/3.12.5/lib/python3.12/site-packages/mod_wsgi/server/mod_wsgi-py312.cpython-312-x86_64-linux-gnu.so /etc/httpd/modules/
        echo "ファイルの確認"
        ls /etc/httpd/modules/
        end_message

        #djangoのインストール
        start_message
        echo "Djangoのインストールをします"
        pip install django
        echo "ファイルの確認"
        pip show django
        echo バージョン確認
        python -m django --version
        end_message

        #プロジェクトの作成
        DIR_PATH=/var/www/html 
        start_message
if [ -d "$DIR_PATH" ]; then
    # ディレクトリが存在した時の処理
    echo ディレクトリ $DIR_PATH はすでに存在します。
    echo プロジェクトを作成します
    echo "cd /var/www/html"
    # ディレクトリ移動
    cd $DIR_PATH
    django-admin startproject mysite .

else
    # ディレクトリが存在しない時の処理
    # ディレクトリを作成する
    mkdir -p $DIR_PATH
    echo ディレクトリ $DIR_PATH を作成しました。
fi

#exit 0

        #全てのAccessを許可する
        echo 外部からのアクセスを許可します
        echo "ALLOWED_HOSTS = [*]"
        sed -i -e '28i ALLOWED_HOSTS = ["*"] \n'  /var/www/html/mysite/settings.py
        sed -i -e "30d" /var/www/html/mysite/settings.py
        #言語設定
        sed -i -e "107d" /var/www/html/mysite/settings.py
        sed -i -e "107i  LANGUAGE_CODE = 'ja' \n"  /var/www/html/mysite/settings.py
        #タイムゾーンを修正
        sed -i -e "110d" /var/www/html/mysite/settings.py
        sed -i -e "109i  TIME_ZONE = 'Asia/Tokyo' \n"  /var/www/html/mysite/settings.py

        end_message


        #ユーザー作成
        start_message
        echo "ユーザーを作成します"
        USERNAME='user'
        PASSWORD=$(more /dev/urandom  | tr -d -c '[:alnum:]' | fold -w 10 | head -1)

        useradd -m -G apache -s /bin/bash "${USERNAME}"
        echo "${PASSWORD}" | passwd --stdin "${USERNAME}"
        echo "パスワードは"${PASSWORD}"です。"

        #所属グループ表示
        echo "所属グループを表示します"
        getent group apache
        end_message

        # apacheの起動
        echo "apacheを起動します"
        start_message
        systemctl start httpd.service

        echo "apacheのステータス確認"
        systemctl status httpd.service
        end_message

        #自動起動の設定
        start_message
        systemctl enable httpd
        systemctl list-unit-files --type=service | grep httpd
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
        http://IPアドレス
        https://IPアドレス
        で確認してみてください

        ドキュメントルート(DR)は
        /var/www/html
        となります。

        htaccessはドキュメントルートのみ有効化しています

        有効化の確認

        https://www.logw.jp/server/7452.html
        vi /var/www/html/.htaccess
        -----------------
        AuthType Basic
        AuthName hoge
        Require valid-user
        -----------------
        ダイアログがでればhtaccessが有効かされた状態となります。


        ●HTTP2について
        このApacheはHTTP/2に非対応となります。ApacheでHTTP2を使う場合は2.4.17以降が必要となります。

        ドキュメントルートの所有者：centos
        グループ：apache
        になっているため、ユーザー名とグループの変更が必要な場合は変更してください
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
