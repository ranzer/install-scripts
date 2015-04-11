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

tonl() {
  exec 3>&1
  exec 4>&2
  exec 1>install.log
  exec 2>errors.log
}

tofl() {
  exec 1>&3
  exec 2>&4
  exec 3>&-
  exec 4>&-
}

print() {
  if [ "$1" ]
  then
    echo -e $1>&3
  fi
}

read_option() {
  print "Enter option: "
  read option
}

create_directory() {
  print "Checking if '$1' directory exists ..."
  if [ -d $1 ]
  then
    print "The directory '$1' exists."
  else
    print "The directory '$1' doesn't exist, creating it ..."
    sudo mkdir $1
    print "The directory '$1' created."
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
     install_ruby;;
   14)
     install_rubygems;;
   15)
     install_rails;;
   16)
      install_redmine;;
  esac
}

install_nginx_using_yum() {
 if [ -f /usr/sbin/nginx ]
 then
   print "Nginx is already installed."
 else
   print "Installing nginx ..."
   sudo yum -y install nginx
   print "Nginx is installed."
   print "Enabling Nginx service to start when system boots ..."
   sudo systemctl enable nginx.service
   print "Nginx service auto start enabled."
   print "Checking if 'sites-available' and 'sites-enabled' directories exists ..."
   create_directory /etc/nginx/sites-available
   create_directory /etc/nginx/sites-enabled
 fi
}

install_nginx_prerequisites() {
  print '  Installing prerequisites ...'
  packages=('gcc' 'gcc-c++' 'make' 'zlib-devel' 'pcre-devel' 'openssl-devel')
  for value in ${packages[*]}
  do
    print "    Installing $value ..."
    sudo yum -q -e 0 install $value 2> /dev/null
    if [ $? -eq 0 ]
    then
      print "    Package $value installed successfully."
    else
      print "${red}    Package $value install fail.${noc}"
      print '    Nginx prerequisites install aborted.'
      exit 1
    fi
  done
  print 'Nginx prerequisites installed completed.'
}

install_nginx_without_yum() {
  nginxVersion = '1.7.7'
  nginxArchive = 'nginx-$nginxVersion.tar.gz'
  nginxFolder = 'nginx-$nginxVersion'
  print 'Installing Nginx without yum ...'
  install_nginx_prerequisites
  if [ $? -eq 0 ]
  then
    print '  Downloading Nginx archive ...'
    curl -# -O 'http://nginx.org/download/$nginxArchive'
    print '  Nginx archive downloaded.'
    print '  Unpacking archive ...'
    tar -xvzf $nginxArchive &> /dev/null
    print '  Unpacked archive.'
    if [ $? -ne 0 ]
    then
      print " ${red}The archive $nginxArchive is not valid.${noc}"
    else
      cd $nginxFolder
      print '  Running configure script ...'
      ./configure --user=nginx --group=nginx --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --with-http_ssl_module --with-pcre
      print '  Configure script executed.'
      print '  Running make command ...'
      make
      if [ $? -ne 0 ]
      then
        print "  ${red}make command failed.${noc}"
      else
        print '  Running make install command ...'
        sudo make install 
        if [ $? -ne 0 ]
        then
          print "  ${red}make install command failed.${noc}"
        fi
      fi
    fi
  fi
}

install_php() {
  print "Installing PHP 5.6 ..."
  print "  Adding yum repositories ..."
  sudo rpm -Uvh https://mirror.webtatic.com/yum/el7/epel-release.rpm
  sudo rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
  print "  yum repositories added."
  print "  Installing yum packages ..."
  sudo yum -y install php56w php56w-devel php56w-mysql php56w-fpm php56w-phpdbg
  print "  Packages installed."
  print "  Modifying /etc/php-fpm.d/www.conf file ..."
  sudo sed 's/listen.\+/listen = \/var\/run\/php-fpm\/php-fpm.sock/' /etc/php-fpm.d/www.conf
  print "    Changed the 'listen' parameter."
  print "  Restarting php-fpm service ..."
  sudo systemctl restart php-fpm
  print "  The php-fpm service restarted."
  print "  Enabling php-fpm service to start on boot ..."
  sudo systemctl enable php-fpm.service
  print "  The php-fpm service enabled to start on boot."
}

install_mariadb() {
  print "Installing MariaDB database ..."
  sudo yum -y install mariadb-server mariadb
  print "MariaDB database installed."
  print "Enabling MariaDB service to start when system boots ..."
  sudo chkconfig mysql on
  print "MariaDB service auto start enabled."
  print "Starting MariaDB ..."
  sudo /etc/init.d/mysql start
  print "MariaDB started."
}

secure_mariadb() {
 print "Securing MariaDB installation ..."
 sh mysql_secure_installation
 print "MariaDB installation secured."
}

secure_php() {
  print "Securing PHP installation ..."
  print "  Modifying /etc/php.ini file ..."
  sudo sed -i 's/;\{0,1\}cgi.fix_pathinfo[ ]*=[ ]*[01]/cgi.fix_pathinfo=0/' /etc/php.ini
  print "    cgi.fix_pathinfo value changed to 0."
  print "  Finished /etc/php.ini file modifications."
  print "Finished securing PHP installation."
}


install_nodejs() {
  print "Enter node.js version you wish to install: "
  read ver
  localDir=`readlink -f ~/.local`
  nodePath=`which node`
  if [ $? -eq 0 ]
  then
    currentVersion=`node -v`
    nodeInstallDir=`readlink -f ~/node-$currentVersion-install`
    print "  Uninstalling previous version of node.js ..."
    if [ ! -d $localDir ]; then print "  ${red}There is no $localDir folder, aborting node uninstall.${noc}"; fi
    if [ ! -d $nodeInstallDir ]; then print "  ${red}There is no $nodeInstallDir folder, aborting node uninstall.${noc}"; fi
    cd $nodeInstallDir
    ./configure --prefix=$localDir
    make uninstall
    if [ $? -ne 0 ]; then print "  ${red}Make uninstall failed.${noc}"; fi
    if [ -f $nodePath ]
    then
      rm $nodePath
      if [ $? -ne 0 ]; then print "  ${red}Failed to remove $nodePath.${noc}"; fi
  fi
    print "  node.js uninstall completed."
    npmPath=`which npmPath`
    if [ $? -eq 0 ]
    then
      print "  Uninstalling npm ..."
      rm $npmPath
      if [ $? -ne 0 ]; then print "  ${red}Failed to remove npm link.${noc}"; fi
      rm -R $localDir/lib/node_modules/npm
      if [ $? -ne 0 ]; then print "  ${red}Failed to remove npm installation.${noc}"; fi
      print "  npm uninstall completed."
    fi
  fi
  nodeInstallDir=`readlink -f ~/node-v$ver-install`
  print "Installing node.js version $ver"
  print "Creating $localDir and $nodeInstallDir directories ..."
  if [ ! -d $localDir ]; then
    mkdir $localDir
    cd $localDir
  fi
  if [ -d $nodeInstallDir ]; then
    rm -f -d -r -v $nodeInstallDir
  fi
  mkdir $nodeInstallDir
  cd $nodeInstallDir
  print "  Downloading archive nodejs.org repository ..."
  cmd="curl -# -O http://nodejs.org/dist/v$ver/node-v$ver.tar.gz"
  eval $cmd
  if [ $? -ne 0 ]; then
    print "  ${red}Couldn't download node.js installation.${noc}"
    exit 1
  fi
  print "  Download complete."
  print "  Unpacking archive ..."
  tar --strip-components=1 -xzf node-v$ver.tar.gz
  print "  Completed."
  print "  Running configure script ..."
  ./configure --prefix=`readlink -e ~/.local`
  print "  Completed."
  print "  Running make install ..."
  make install
  print "  Completed."
}

install_npm() {
  print "  Downloading npm install script ..."
  curl -# -O -L https://www.npmjs.org/install.sh
  print "  Completed."
  print "  Installing npm ..."
  . install.sh
  print "  Completed."
}

install_rvm() {
  print "Installing Ruby Version Manager ..."
  print "  Installing gpg public key ..."
  curl -sSL https://rvm.io/mpapis.asc | gpg --import - || { print "  ${red}Failed to install_redmine gpg public key.${noc} Installation aborted."; exit 1; }
  print "  Completed."
  print "  Downloading and executing RVM stable installation script ..."
  curl -sSL https://get.rvm.io | bash -s stable || { print "  ${red}Failed to download or execute RVM installation script.${noc} Installation aborted."; exit 1; }
  print "  RVM downloading and executing completed."
  print "  Loading RVM ..."
  source ~/.profile || { print "  Failed to load RVM."; }
  print "RVM installation completed."
}

install_ruby() {
  print "Installing Ruby ..."
  print "  Searching for the Ruby Version Manager ..."
  which rvm &> /dev/null || { print "  The Ruby Version Manager doesn't exist. Install the Ruby Version Manager prior installing Ruby."; exit 1; }
  print "  Completed."
  print "  Which Ruby version do you want to install?"
  read ver
  print "  Installing Ruby $ver ..."
  rvm install $ver || { print "  ${red}Failed to install Ruby $ver.${noc}"; exit 1; }
  print "  Completed."
  print "  Setting Ruby $ver as default version to be used ..."
  rvm use $ver --default || { print "  ${red}Failed to set Ruby $ver as default version to be used.${noc}"; exit 1; }
  print "  Completed."
  install_rubygems
  print "Completed."
}

install_rubygems() {
  print "Installing RubyGems ..."
  print "  Searching for the Ruby Version Manager ..."
  which rvm &> /dev/null || { print "  The Ruby Version Manager doesn't exist. Install the Ruby Version Manager prior installing Ruby."; exit 1; }
  print "  Completed."
  print "  Installing the most recent RubyGems ..."
  rvm rubygems current || { print "  ${red}Failed to install RubyGems.${noc}"; exit 1; }
  print "  Completed."
  print "Completed."
}

install_rails() {
  print "Enter Rails version you wish to install"
  read ver
  print "Installing Rails"
  print "  Search for RubyGems ..."
  which rvm &> /dev/null || { print "  The RubyGems doesn't exist. Install RubyGems prior installing Rails."; exit 1; }
  print "  Completed."
  print "  Installing Rails $ver ..."
  gem install rails -v $ver || { print "  ${red}Failed to install Rails $ver.${noc}"; exit 1; }
  print "  Completed."
  print "Completed."
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
