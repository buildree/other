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

        #mod_sslのインストール
        start_message
        yum -y install mod_ssl
        end_message

        #MariaDBを削除
        start_message
        echo "MariaDBを削除します"
        echo ""
        yum -y remove mariadb-libs
        rm -rf /var/lib/mysql/
        end_message


        # yum updateを実行
        echo "yum updateを実行します"
        echo ""

        start_message
        #yum -y update
        end_message

        #nginxの設定ファイルを作成
        start_message
        echo "nginxのインストールファイルを作成します"
        cat >/etc/yum.repos.d/nginx.repo <<'EOF'
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/7/$basearch/
gpgcheck=0
enabled=1
EOF
        end_message

        #nginxのインストール
        start_message
        yum  -y --enablerepo=nginx install nginx
        end_message

        #SSLの設定ファイルに変更
        start_message
        echo "ファイルのコピー"
        cp -p /etc/pki/tls/certs/localhost.crt /etc/nginx
        cp -p /etc/pki/tls/private/localhost.key /etc/nginx/

        #バージョン非表示
        sed -i -e "30a \     #バージョン非表示" /etc/nginx/nginx.conf
        sed -i -e "31a \     server_tokens off;\n" /etc/nginx/nginx.conf
        cat /etc/nginx/nginx.conf


        echo "ファイルを変更"
        mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bk
        cat >/etc/nginx/conf.d/default.conf <<'EOF'
server {
    listen       80;
    server_name  localhost;
    #return 301 https://$http_host$request_uri;

    #gzip
       gzip on;
       gzip_types image/png image/gif image/jpeg text/javascript text/css;
       gzip_min_length 1000;
       gzip_proxied any;
       gunzip on;


    #charset koi8-r;
    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        #root   /usr/share/nginx/html;
        #index  index.php index.html index.htm;
        proxy_pass      http://localhost:6000;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}


server {
    listen 443 ssl http2;
    server_name  localhost;

    #charset koi8-r;
    #access_log  /var/log/nginx/host.access.log  main;

    #mod_sslのオレオレ証明書を使用
    ssl_certificate /etc/nginx/localhost.crt;
    ssl_certificate_key /etc/nginx/localhost.key;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers HIGH:!aNULL:!MD5;
    #ssl_prefer_server_ciphers on;
    #ssl_ciphers 'kEECDH+ECDSA+AES128 kEECDH+ECDSA+AES256 kEECDH+AES128 kEECDH+AES256 kEDH+AES128 kEDH+AES256 DES-CBC3-SHA +SHA !DH !aNULL !eNULL !LOW !kECDH !DSS !MD5 !EXP !PSK !SRP !CAMELLIA !SEED';
    ssl_session_cache    shared:SSL:10m;
    ssl_session_timeout  10m;

    #gzip
       gzip on;
       gzip_types image/png image/gif image/jpeg text/javascript text/css;
       gzip_min_length 1000;
       gzip_proxied any;
       gunzip on;


    location / {
        #root   /usr/share/nginx/html;
        #index  index.php index.html index.htm;
        proxy_pass      http://localhost:6000;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
EOF
        end_message

        #MySQLの選択
        PS3="インストールしたいMySQLのバージョンを選んでください > "
        ITEM_LIST="MySQL5.7 MySQL8.0"

        select selection in $ITEM_LIST
        do
          if [ $selection = "MySQL5.7" ]; then

            #公式リポジトリの追加
            start_message
            yum -y localinstall http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
            yum info mysql-community-server
            end_message

            #MySQLのインストール
            start_message
            echo "MySQLのインストール"
            echo ""
            yum -y install mysql-community-server
            yum list installed | grep mysql
            end_message

            #バージョン確認
            start_message
            echo "MySQLのバージョン確認"
            echo ""
            mysql --version
            end_message

            #my.cnfの設定を変える
            start_message
            echo "ファイル名をリネーム"
            echo "/etc/my.cnf.default"
            mv /etc/my.cnf /etc/my.cnf.default
            mkdir /var/log/mysql/

            echo "新規ファイルを作成してパスワードを無制限使用に変える"
            cat <<EOF >/etc/my.cnf
# For advice on how to change settings please see
# http://dev.mysql.com/doc/refman/5.7/en/server-configuration-defaults.html

[mysqld]
#
# Remove leading # and set to the amount of RAM for the most important data
# cache in MySQL. Start at 70% of total RAM for dedicated server, else 10%.
# innodb_buffer_pool_size = 128M
#
# Remove leading # to turn on a very important data integrity option: logging
# changes to the binary log between backups.
# log_bin
#
# Remove leading # to set options mainly useful for reporting servers.
# The server defaults are faster for transactions and fast SELECTs.
# Adjust sizes as needed, experiment to find the optimal values.
# join_buffer_size = 128M
# sort_buffer_size = 2M
# read_rnd_buffer_size = 2M
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock

# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

character-set-server = utf8
default_password_lifetime = 0

#slowクエリの設定
slow_query_log=ON
slow_query_log_file=/var/log/mysql-slow.log
long_query_time=0.01
EOF
            end_message
            break
          elif [ $selection = "MySQL8.0" ]; then

            #公式リポジトリの追加
            start_message
            rpm -ivh https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm
            yum info mysql-community-server
            end_message

            #MySQLのインストール
            start_message
            echo "MySQLのインストール"
            echo ""
            yum -y install mysql-community-server --enablerepo=mysql80-community
            yum list installed | grep mysql
            end_message

            #バージョン確認
            start_message
            echo "MySQLのバージョン確認"
            echo ""
            mysql --version
            end_message

            #my.cnfの設定を変える
            start_message
            echo "ファイル名をリネーム"
            echo "/etc/my.cnf.default"
            mv /etc/my.cnf /etc/my.cnf.default

            echo "新規ファイルを作成してパスワードを無制限使用に変える"
cat <<EOF >/etc/my.cnf
# For advice on how to change settings please see
# http://dev.mysql.com/doc/refman/8.0/en/server-configuration-defaults.html

[mysqld]
#
# Remove leading # and set to the amount of RAM for the most important data
# cache in MySQL. Start at 70% of total RAM for dedicated server, else 10%.
# innodb_buffer_pool_size = 128M
#
# Remove the leading "# " to disable binary logging
# Binary logging captures changes between backups and is enabled by
# default. It's default setting is log_bin=binlog
# disable_log_bin
#
# Remove leading # to set options mainly useful for reporting servers.
# The server defaults are faster for transactions and fast SELECTs.
# Adjust sizes as needed, experiment to find the optimal values.
# join_buffer_size = 128M
# sort_buffer_size = 2M
# read_rnd_buffer_size = 2M
#
# Remove leading # to revert to previous value for default_authentication_plugin,
# this will increase compatibility with older clients. For background, see:
# https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_default_authentication_plugin
# default-authentication-plugin=mysql_native_password

datadir=/var/lib/mysql
log-error=/var/log/mysqld.log
socket=/var/lib/mysql/mysql.sock

character-set-server = utf8mb4
collation-server = utf8mb4_bin
default_password_lifetime = 0

#旧式のログインに変更
default_authentication_plugin=mysql_native_password

#slowクエリの設定
slow_query_log=ON
slow_query_log_file=/var/log/mysql-slow.log
long_query_time=0.01
EOF
            end_message

            break
          else
            echo "どれかを選択してください"
          fi
        done

        #gogsのインストール
        start_message
        echo "gogsのインストールをする"
        wget -O /etc/yum.repos.d/gogs.repo \
  https://dl.packager.io/srv/gogs/gogs/master/installer/el/7.repo
        yum install -y gogs
        end_message


        #ユーザー作成
        start_message
        echo "centosユーザーを作成します"
        USERNAME='centos'
        PASSWORD=$(more /dev/urandom  | tr -d -c '[:alnum:]' | fold -w 10 | head -1)

        #gogsユーザー作成
        echo "gogsユーザーを作成します"
        gogsUSERNAME='gogs'
        gogsPASSWORD=$(more /dev/urandom  | tr -d -c '[:alnum:]' | fold -w 10 | head -1)

        #DBrootユーザーのパスワード
        RPASSWORD=$(more /dev/urandom  | tr -dc '12345678abcdefghijkmnpqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ,.+\-\!' | fold -w 12 | grep -i [12345678] | grep -i '[,.+\-\!]' | head -n 1)
        #DBuser(centos)パスワード
        UPASSWORD=$(more /dev/urandom  | tr -dc '12345678abcdefghijkmnpqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ,.+\-\!' | fold -w 12 | grep -i [12345678] | grep -i '[,.+\-\!]' | head -n 1)



        useradd -m -G apache -s /bin/bash "${USERNAME}"
        echo "${PASSWORD}" | passwd --stdin "${USERNAME}"
        echo "パスワードは"${PASSWORD}"です。"

        #所属グループ表示
        echo "所属グループを表示します"
        getent group nginx
        end_message

        #所有者の変更
        start_message
        echo "ドキュメントルートの所有者をcentos、グループをnginxにします"
        chown -R centos:nginx /usr/share/nginx/html
        end_message



        #nginxの起動
        start_message
        echo "nginxの起動"
        echo ""
        systemctl start nginx
        systemctl start mysqld
        systemctl status nginx
        systemctl status mysqld
        end_message

        #自動起動の設定
        start_message
        systemctl enable nginx
        systemctl list-unit-files --type=service | grep nginx
        systemctl list-unit-files --type=service | grep mysql
        end_message

        #パスワード設定
        start_message
        DB_PASSWORD=$(grep "A temporary password is generated" /var/log/mysqld.log | sed -s 's/.*root@localhost: //')
        #sed -i -e "s|#password =|password = '${DB_PASSWORD}'|" /etc/my.cnf
        mysql -u root -p${DB_PASSWORD} --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${RPASSWORD}'; flush privileges;"
        echo ${RPASSWORD}

cat <<EOF >/etc/createdb.sql
CREATE DATABASE centos;
CREATE USER 'centos'@'localhost' IDENTIFIED BY '${UPASSWORD}';
GRANT ALL PRIVILEGES ON centos.* TO 'centos'@'localhost';
FLUSH PRIVILEGES;
SELECT user, host FROM mysql.user;
EOF
mysql -u root -p${RPASSWORD}  -e "source /etc/createdb.sql"

        end_message

        #ファイルを保存
        cat <<EOF >/etc/my.cnf.d/centos.cnf
[client]
user = centos
password = ${UPASSWORD}
host = localhost
EOF

        systemctl restart mysqld.service

        #ファイルの保存
        start_message
        echo "パスワードなどを保存"
        cat <<EOF >/root/pass.txt
root = ${RPASSWORD}
centos = ${UPASSWORD}
gogs = ${gogsPASSWORD}
EOF
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


        ---------------------------------------
        httpsリダイレクトについて
        /etc/nginx/conf.d/default.conf
        #return 301 https://$http_host$request_uri;
        ↑
        コメントを外せばそのままリダイレクトになります。
        ---------------------------------------

        ドキュメントルートの所有者：centos
        グループ：nginx
        になっているため、ユーザー名とグループの変更が必要な場合は変更してください

        -----------------

EOF

        echo "centosユーザーのパスワードは"${PASSWORD}"です。"
        echo "gogsユーザーのパスワードは"${gogsPASSWORD}"です。"
        echo "データベースのrootユーザーのパスワードは"${RPASSWORD}"です。"
        echo "データベースのcentosユーザーのパスワードは"${UPASSWORD}"です。"

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
