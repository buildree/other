#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
作成者：サイトラボ
URL：https://www.site-lab.jp/
URL：https://buildree.com/

Pythonのインストールを行います

COMMENT

echo ""

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

        #gitなど必要な物をインストール
        start_message
        yum install -y gcc gcc-c++ make git openssl-devel zlib-devel readline-devel sqlite-devel bzip2-devel libffi-devel
        end_message


        # yum updateを実行
        start_message
        echo "yum updateを実行します"
        echo ""
        yum -y update
        end_message

        #pyenvの設定
        start_message
        echo "gitでpyenvをクーロンします"
        git clone https://github.com/yyuu/pyenv.git /usr/local/pyenv
        git clone https://github.com/yyuu/pyenv-virtualenv.git /usr/local/pyenv/plugins/pyenv-virtualenv
        end_message

        #pyenvのインストール
        start_message
        echo "起動時に読み込まれるようにします"
        cat >/etc/profile.d/pyenv.sh <<'EOF'
export PYENV_ROOT="/usr/local/pyenv"
export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init --path)"
EOF

        source /etc/profile.d/pyenv.sh
        end_message

        #pythonの確認
        start_message
        echo "pythonのリスト確認"
        pyenv install --list
        echo "python3.10.3のインストール"
        env PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install 3.10.3
        echo "pythonの設定を変更"
        pyenv global 3.10.3
        end_message

        #pythonの確認
        start_message
        echo "pythonの位置を確認"
        which python
        echo "pythonのバージョン確認"
        python --version
        end_message

        #pipのアップグレード
        start_message
        echo "pipのアップグレード"
        pip install --upgrade pip
        end_message


        #ユーザー作成
        start_message
        echo "centosユーザーを作成します"
        USERNAME='centos'
        PASSWORD=$(more /dev/urandom  | tr -d -c '[:alnum:]' | fold -w 10 | head -1)

        useradd -m -G nobody -s /bin/bash "${USERNAME}"
        echo "${PASSWORD}" | passwd --stdin "${USERNAME}"
        echo "パスワードは"${PASSWORD}"です。"
        end_message

        umask 0002

        #ファイルの保存
        start_message
        echo "パスワードなどを保存"
        cat <<EOF >/root/pass.txt
ログインユーザー
centos = ${PASSWORD}
EOF

        #コピー作成
        cp /root/pass.txt /home/centos/
        chown -R centos:nobody /home/centos
        end_message



        #サンプルファイル作成
        start_message
        cat > /home/centos/hello.py <<'EOF'
#coding:UTF-8

print ("こんにちは世界！")
EOF
        end_message

        #実行
        start_message
        echo "実行します"
        echo "python hello.py"
        su -l centos -c "python hello.py"
        #python hello.py
        end_message

        #sphinxのインストール
        echo "sphinxのインストール"
        start_message
        echo "pip install sphinx Pillow"
        pip install sphinx Pillow

        echo "バージョン確認"
        echo "sphinx-quickstart --version"
        sphinx-quickstart --version

        echo "インストール場所確認"
        pip show sphinx
        end_message

        cat <<EOF
-----------------
Python+sphinxのインストールとなります
sphinxの使い方はSphinx-Users.jpを閲覧してください
https://sphinx-users.jp/index.html
-----------------
パスワードのテキストファイルは、rootとcentosと両方にあります
-----------------
EOF
        echo "centosユーザーのパスワードは"${PASSWORD}"です。"
        #所有者変更
        start_message
        chown -R centos:nobody /home/centos/
        su -l centos
        end_message


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
