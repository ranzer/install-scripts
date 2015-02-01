#!/bin/bash

option = -1
red='\033[0;31m'
noc='\033[0m'

print_usage() {
  cat <<EOF
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
  packages = ('gcc' 'gcc-c++' 'make' 'zlib-devel' 'pcre-devel' 'openssl-devel')
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
  nginxFolder = 'nginx-nginxVersion'
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
      echo ' ${red}The archive $nginxArchive is not valid.${noc}'
    else
      cd $nginxFolder
      echo '  Running configure script ...'
      ./configure --user=nginx --group=nginx --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --with-http_ssl_module --with-pcre
      echo '  Configure script executed.'
      echo '  Running make command ...'
      make
      if [ $? -ne 0 ]
      then
        echo '  ${red}make command failed.${noc}'
      else
        echo '  Running make install command ...'
        sudo make install 
        if [ $? -ne 0 ]
        then
          echo "  ${red}make install command failed.$[noc}"
        else
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

print_usage
read_option
install


