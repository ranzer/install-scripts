#!/bin/bash

option=-1
red='\e[31m'
noc='\e[0m'

print_usage() {
  cat >&3 <<EOF
Choose one of the options:
  1. Install Nginx using yum
  2. Install Nginx without yum
  3. Configure Nginx
  4. Install PHP
  5. Configure PHP
  6. Install MariaDB
  7. Configure MariaDB
  8. Secure PHP installation
  9. Secure MySQL installation
 10. Install node.js
 11. Install npm
 12. Install RVM
 13. Install Ruby
 14. Install RubyGems
 15. Install Rails
 16. Install Redmine
EOF
}

read_option() {
  read -p "Enter option: " option
}

create_directory() {
  echo "Checking if '$1' directory exists ..."
  if [ -d $1 ]
  then
    echo "The directory '$1' exists."
  else
    echo "The directory '$1' doesn't exist, creating it ..."
    sudo mkdir $1
    echo "The directory '$1' created."
  fi
}

install() {
  case $option in
    1) 
      install_nginx_with_yum;;
    2)
      install_nginx_without_yum;;
    3)
      configure_nginx;;
    4) 
      install_php;;
    5)
      configure_php;;
    6)
      install_mariadb;;
    7)
      configure_mariadb;;
    8)
      secure_php;;
    9)
      secure_mariadb;;
   10)
      install_nodejs;;
   11)
      install_npm;;
   12)
      install_rvm;;
   13)
      install_redmine;;
  esac
}

install_nginx_using_yum() {
 if [ -f /usr/sbin/nginx ]
 then
   echo "Nginx is already installed."
 else
   echo "Installing nginx ..."
   sudo yum -y install nginx
   echo "Nginx is installed."
   echo "Enabling Nginx service to start when system boots ..."
   sudo systemctl enable nginx.service
   echo "Nginx service auto start enabled."
   echo "Checking if 'sites-available' and 'sites-enabled' directories exists ..."
   create_directory /etc/nginx/sites-available
   create_directory /etc/nginx/sites-enabled
 fi
}

install_nginx_prerequisites() {
  echo '  Installing prerequisites ...'
  packages=('gcc' 'gcc-c++' 'make' 'zlib-devel' 'pcre-devel' 'openssl-devel')
  for value in ${packages[*]}
  do
    echo "    Installing $value ..."
    sudo yum -q -e 0 install $value 2> /dev/null
    if [ $? -eq 0 ]
    then
      echo "    Package $value installed successfully."
    else
      echo -e "${red}    Package $value install fail.${noc}"
      echo '    Nginx prerequisites install aborted.'
      exit 1
    fi
  done
  echo 'Nginx prerequisites installed completed.'
}

install_nginx_without_yum() {
  nginxVersion = '1.7.7'
  nginxArchive = 'nginx-$nginxVersion.tar.gz'
  nginxFolder = 'nginx-$nginxVersion'
  echo 'Installing Nginx without yum ...'
  install_nginx_prerequisites
  if [ $? -eq 0 ]
  then
    echo '  Downloading Nginx archive ...'
    curl -# -O 'http://nginx.org/download/$nginxArchive'
    echo '  Nginx archive downloaded.'
    echo '  Unpacking archive ...'
    tar -xvzf $nginxArchive &> /dev/null
    echo '  Unpacked archive.'
    if [ $? -ne 0 ]
    then
      echo -e " ${red}The archive $nginxArchive is not valid.${noc}"
    else
      cd $nginxFolder
      echo '  Running configure script ...'
      ./configure --user=nginx --group=nginx --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --with-http_ssl_module --with-pcre
      echo '  Configure script executed.'
      echo '  Running make command ...'
      make
      if [ $? -ne 0 ]
      then
        echo -e "  ${red}make command failed.${noc}"
      else
        echo '  Running make install command ...'
        sudo make install 
        if [ $? -ne 0 ]
        then
          echo -e "  ${red}make install command failed.${noc}"
        fi
      fi
    fi
  fi
}

install_php() {
  echo "Installing PHP 5.6 ..."
  echo "  Adding yum repositories ..."
  sudo rpm -Uvh https://mirror.webtatic.com/yum/el7/epel-release.rpm
  sudo rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
  echo "  yum repositories added."
  echo "  Installing yum packages ..."
  sudo yum -y install php56w php56w-devel php56w-mysql php56w-fpm php56w-phpdbg
  echo "  Packages installed."
  echo "  Modifying /etc/php-fpm.d/www.conf file ..."
  sudo sed 's/listen.\+/listen = \/var\/run\/php-fpm\/php-fpm.sock/' /etc/php-fpm.d/www.conf
  echo "    Changed the 'listen' parameter."
  echo "  Restarting php-fpm service ..."
  sudo systemctl restart php-fpm
  echo "  The php-fpm service restarted."
  echo "  Enabling php-fpm service to start on boot ..."
  sudo systemctl enable php-fpm.service
  echo "  The php-fpm service enabled to start on boot."
}

install_mariadb() {
  echo "Installing MariaDB database ..."
  sudo yum -y install mariadb-server mariadb
  echo "MariaDB database installed."
  echo "Enabling MariaDB service to start when system boots ..."
  sudo chkconfig mysql on
  echo "MariaDB service auto start enabled."
  echo "Starting MariaDB ..."
  sudo /etc/init.d/mysql start
  echo "MariaDB started."
}

secure_mariadb() {
 echo "Securing MariaDB installation ..."
 sh mysql_secure_installation
 echo "MariaDB installation secured."
}

secure_php() {
  echo "Securing PHP installation ..."
  echo "  Modifying /etc/php.ini file ..."
  sudo sed -i 's/;\{0,1\}cgi.fix_pathinfo[ ]*=[ ]*[01]/cgi.fix_pathinfo=0/' /etc/php.ini
  echo "    cgi.fix_pathinfo value changed to 0."
  echo "  Finished /etc/php.ini file modifications."
  echo "Finished securing PHP installation."
}


install_nodejs() {
  read -p "Enter node.js version you wish to install: " ver
  localDir=`readlink -f ~/.local`
  nodePath=`which node`
  if [ $? -eq 0 ]
  then
    currentVersion=`node -v`
    nodeInstallDir=`readlink -f ~/node-$currentVersion-install`
    echo "  Uninstalling previous version of node.js ..."
    if [ ! -d $localDir ]; then echo -e "  ${red}There is no $localDir folder, aborting node uninstall.${noc}"; fi
    if [ ! -d $nodeInstallDir ]; then echo -e "  ${red}There is no $nodeInstallDir folder, aborting node uninstall.${noc}"; fi
    cd $nodeInstallDir
    ./configure --prefix=$localDir
    make uninstall
    if [ $? -ne 0 ]; then echo -e "  ${red}Make uninstall failed.${noc}"; fi
    if [ -f $nodePath ]
    then
      rm $nodePath
      if [ $? -ne 0 ]; then echo -e "  ${red}Failed to remove $nodePath.${noc}"; fi
    fi
    echo "  node.js uninstall completed."
    npmPath=`which npmPath`
    if [ $? -eq 0 ]
    then
      echo "  Uninstalling npm ..."
      rm $npmPath
      if [ $? -ne 0 ]; then echo -e "  ${red}Failed to remove npm link.${noc}"; fi
      rm -R $localDir/lib/node_modules/npm
      if [ $? -ne 0 ]; then echo -e "  ${red}Failed to remove npm installation.${noc}"; fi
      echo "  npm uninstall completed."
    fi
fi
  nodeInstallDir=`readlink -f ~/node-v$ver-install`
  echo "Installing node.js version $ver"
  echo "Creating $localDir and $nodeInstallDir directories ..."
  if [ ! -d $localDir ]; then
    mkdir $localDir
    cd $localDir
  fi
  if [ -d $nodeInstallDir ]; then
    rm -f -d -r -v $nodeInstallDir
fi
  mkdir $nodeInstallDir
  cd $nodeInstallDir
  echo "  Downloading archive nodejs.org repository ..."
  cmd="curl -# -O http://nodejs.org/dist/v$ver/node-v$ver.tar.gz"
  eval $cmd
  if [ $? -ne 0 ]; then
    echo -e "  ${red}Couldn't download node.js installation.${noc}"
    exit 1
  fi
  echo "  Download complete."
  echo "  Unpacking archive ..."
  tar --strip-components=1 -xzf node-v$ver.tar.gz
  echo "  Completed."
  echo "  Running configure script ..."
  ./configure --prefix=`readlink -e ~/.local`
  echo "  Completed."
  echo "  Running make install ..."
  make install
  echo "  Completed."
}

function install_npm() {
  echo "  Downloading npm install script ..."
  curl -# -O -L https://www.npmjs.org/install.sh
  echo "  Completed."
  echo "  Installing npm ..."
  . install.sh
  echo "  Completed."
}

function install_rvm() {
  echo "Installing Ruby Version Manager ..."
  echo "  Installing gpg public key ..."
  curl -sSL https://rvm.io/mpapis.asc | gpg --import - || { echo -e "  ${red}Failed to install_redminell gpg public key.${noc} Installation aborted."; exit 1; }
  echo "  Completed."
  echo "  Downloading and executing RVM stable installation script ..."
  curl -sSL https://get.rvm.io | bash -s stable || { echo -e "  ${red}Failed to download or execute RVM installation script.${noc} Installation aborted."; exit 1; }
  echo "  RVM downloading and executing completed."
  echo "  Loading RVM ..."
  source ~/.profile || { echo "  Failed to load RVM." }
  echo "RVM installation completed."
}

function install_redmine() {
  echo "Installing redmine ..."
  echo "  Installing prerequisites ..."
  sudo yum install zlib-devel curl-devel openssl-devel httpd-devel apr-devel apr-util-devel mysql-devel
  if [ !$? -ne 0 ]; then
    echo -e "${red}  Prerequisites installation failed.${noc}"
    exit 1
  fi
  
}

print_usage
read_option
install
