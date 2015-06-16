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
 17. Install Gateone
 18. Install Jenkins
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
    local indentBy=0
    local text="$1"
    local textSize=${#text}
    if [ "$2" ]
    then
      case "$1" in
        -e) 
            text="${red}$2${noc}"
            textSize=$((${#text} - 2))
            ;;
         *) 
            indentBy=$2
            ;;
      esac
    fi
    if [ "$3" ]
    then
      indentBy=$3
    fi
    local indentSize=$(($textSize + $indentBy))
    printf "%${indentSize}b\n" "$text">&3
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
   17)
     install_gateone;;
   18)
     install_jenkins;;
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

install_packages() {
  if [ ! -z "$1" ]; then
    for package in "$@"
    do
      print "Installing $package ..."
      sudo yum -y install $package || { print "Failed to install $package."; return 1; }
      print "$package installed successfully."
    done
  fi
}

install_nginx_prerequisites() {
  print '  Installing prerequisites ...'
  packages=('gcc' 'gcc-c++' 'make' 'zlib-devel' 'pcre-devel' 'openssl-devel')
  for value in ${packages[*]}
  do
    print "    Installing $value ..."
    sudo yum -y install $value
    if [ $? -eq 0 ]
    then
      print "    Package $value installed successfully."
    else
      print -e "    Package $value install fail."
      print '    Nginx prerequisites install aborted.'
      exit 1
    fi
  done
  print '  Nginx prerequisites installed completed.'
}

install_nginx_without_yum() {
  print " Enter nginx version you want to install:"
  read nginxVersion
  nginxArchive="nginx-$nginxVersion.tar.gz"
  nginxFolder="nginx-$nginxVersion"
  print 'Installing Nginx without yum ...'
  install_nginx_prerequisites
  if [ $? -eq 0 ]
  then
    print '  Downloading Nginx archive ...'
    curl -# -O "http://nginx.org/download/$nginxArchive"
    print '  Nginx archive downloaded.'
    print '  Unpacking archive ...'
    tar -xvzf $nginxArchive &> /dev/null
    print '  Unpacked archive.'
    if [ $? -ne 0 ]
    then
      print -e " The archive $nginxArchive is not valid."
    else
      cd $nginxFolder
      print '  Running configure script ...'
      ./configure --user=nginx --group=nginx --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --with-http_ssl_module --with-pcre
      print '  Configure script executed.'
      print '  Running make command ...'
      make || { print -e "  make command failed."; exit 1; }
      print '  Completed.'
      print '  Running make install command ...'
      sudo make install || { print -e "  make install command failed."; exit 1; }
      print '  Completed.'
    fi
   print "Completed."
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

create_mariadb_package_name() {
  if [ ! -z "$1" ] && [ ! -z "$2" ]; then
    local osname=$(sed -rn 's/^ID="(.*)"/\1/p' /etc/os-release)
    local osversion=$(sed -rn 's/^VERSION_ID="([0-9]+)"/\1/p' /etc/os-release)
    local arch=$(arch)
    if [ ! -z "$3" ]; then
      arch="$3"
    fi
    local packageName="MariaDB-$1-$osname$osversion-$arch-$2"
  fi

  echo $packageName
}

create_mariadb_download_link() {
  if [ ! -z "$1"  ] && [ ! -z "$2" ] && [ ! -z "$3" ]; then
    local mariadbUrl=http://yum.mariadb.org/
    local osname=$(sed -rn 's/^ID="(.*)"/\1/p' /etc/os-release)
    local osversion=$(sed -rn 's/^VERSION_ID="([0-9]+)"/\1/p' /etc/os-release)
    local url="$mariadbUrl/$1/$osname$osversion-$2/rpms/$3.rpm"
  fi

  echo $url
}

install_mariadb_package() {
  if [ ! -z "$1" ] && [ ! -z "$2" ]; then
    local mparch=$(arch | sed -nr 's/(.*)_.*/\1/p')
    local mariadbVersion="$1"
    local packageName=$(create_mariadb_package_name $mariadbVersion "$2")
    local url=$(create_mariadb_download_link $mariadbVersion $mparch $packageName)
    local indentBy=0
    if [ ! -z "$3" ]; then
      indentBy="$3"
    fi
    print "Checking url $url ..." $indentBy
    wget -q --spider "$url"
    if [ $? -ne 0 ]
    then
      mparch="amd64"
      print "Package at url $url doesn't exist." $(($indentBy + 2))
      url=$(create_mariadb_download_link $mariadbVersion $mparch $packageName)
      print "Checking url $url ... " $(($indentBy + 2))
      wget -q --spider "$url" || { print -e "No packages found." $(($indentBy + 2)); exit 1; }
      print "The url $url is valid." $(($indentBy + 2))
    else
      print "The url $url is valid." $(($indentBy + 2))
    fi
    print "MariaDB $mariadbVersion installation found." $(($indentBy + 2))
    print "Check completed." $indentBy
    print "Downloading $url ..." $indentBy
    curl -f -# -O "$url" || { print -e "Failed to download $url." $indentBy; exit 1; }
    print "Completed." $indentBy
    print "Installing package $packageName ..." $indentBy
    sudo rpm -ivh "$packageName.rpm" || { print -e "Failed to install client package." $indentBy; exit 1; }
    print "Completed." $indentBy
  fi
}

install_mariadb() {
  print "Installing MariaDB database ..."
  print "  Enter MariaDB version to install:"
  read mariadbVersion
  install_mariadb_package $mariadbVersion "common" 2
  install_mariadb_package $mariadbVersion "client" 2
  install_mariadb_package $mariadbVersion "server" 2
}

secure_mariadb() {
 tofl
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
  print "  Installing node.js prerequisites ..."
  sudo yum groupinstall -y "Development Tools" || { print -e "  Failed to install node.js prerequisites. Installation aborted."; exit 1; }
  print "  Prerequisites installation completed."
  localDir=`readlink -f ~/.local`
  nodePath=`which node`
  if [ $? -eq 0 ]
  then
    currentVersion=`node -v`
    nodeInstallDir=`readlink -f ~/node-$currentVersion-install`
    print "  Uninstalling previous version of node.js ..."
    if [ ! -d $localDir ]; then print -e "  There is no $localDir folder, aborting node uninstall."; fi
    if [ ! -d $nodeInstallDir ]; then print -e "  There is no $nodeInstallDir folder, aborting node uninstall."; fi
    cd $nodeInstallDir
    ./configure --prefix=$localDir
    make uninstall
    if [ $? -ne 0 ]; then print -e "  Make uninstall failed."; fi
    if [ -f $nodePath ]
    then
      rm $nodePath
      if [ $? -ne 0 ]; then print -e "  Failed to remove $nodePath."; fi
  fi
    print "  node.js uninstall completed."
    npmPath=`which npmPath`
    if [ $? -eq 0 ]
    then
      print "  Uninstalling npm ..."
      rm $npmPath
      if [ $? -ne 0 ]; then print -e "  Failed to remove npm link."; fi
      rm -R $localDir/lib/node_modules/npm
      if [ $? -ne 0 ]; then print -e "  Failed to remove npm installation."; fi
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
  print "Installing npm ..."
  print "  Installing npm prerequisites ..."
  sudo yum groupinstall -y "Development Tools" || { print -e "  Failed to install npm prerequisites. Installation aborted."; exit 1; }
  print "  Prerequisites installation completed."
  print "  Downloading npm install script ..."
  curl -# -O -L https://www.npmjs.org/install.sh
  print "  Completed."
  print "  Running npm installation script ..."
  . install.sh
  print "  Completed."
  print "npm installation completed."
}

install_rvm() {
  print "Installing Ruby Version Manager ..."
  print "  Installing gpg public key ..."
  curl -sSL https://rvm.io/mpapis.asc | gpg --import - || { print -e "  Failed to install_redmine gpg public key. Installation aborted."; exit 1; }
  print "  Completed."
  print "  Downloading and executing RVM stable installation script ..."
  curl -sSL https://get.rvm.io | bash -s stable || { print -e "  Failed to download or execute RVM installation script.${noc} Installation aborted."; exit 1; }
  print "  RVM downloading and executing completed."
  print "  Loading RVM ..."
  source ~/.profile || { print -e "  Failed to load RVM."; }
  print "RVM installation completed."
}

install_ruby() {
  print "Installing Ruby ..."
  print "  Searching for the Ruby Version Manager ..."
  which rvm &> /dev/null || { print -e "  The Ruby Version Manager doesn't exist. Install the Ruby Version Manager prior installing Ruby."; exit 1; }
  print "  Completed."
  print "  Which Ruby version do you want to install?"
  read ver
  print "  Installing Ruby $ver ..."
  rvm install $ver || { print -e "  Failed to install Ruby $ver."; exit 1; }
  print "  Completed."
  print "  Setting Ruby $ver as default version to be used ..."
  rvm use $ver --default || { print -e "  Failed to set Ruby $ver as default version to be used."; exit 1; }
  print "  Completed."
  install_rubygems
  print "Completed."
}

install_rubygems() {
  print "Installing RubyGems ..."
  print "  Searching for the Ruby Version Manager ..."
  which rvm &> /dev/null || { print -e "  The Ruby Version Manager doesn't exist. Install the Ruby Version Manager prior installing Ruby."; exit 1; }
  print "  Completed."
  print "  Installing the most recent RubyGems ..."
  rvm rubygems current || { print -e "  Failed to install RubyGems."; exit 1; }
  print "  Completed."
  print "Completed."
}

install_rails() {
  print "Enter Rails version you wish to install"
  read ver
  print "Installing Rails"
  print "  Search for RubyGems ..."
  which rvm &> /dev/null || { print -e "  The RubyGems doesn't exist. Install RubyGems prior installing Rails."; exit 1; }
  print "  Completed."
  print "  Installing Rails $ver ..."
  gem install rails -v $ver || { print -e "  Failed to install Rails $ver."; exit 1; }
  print "  Completed."
  print "Completed."
}

install_redmine() {
  webServerPublicDir=/usr/share/nginx/html
  print "Installing redmine ..."
  print "  Installing prerequisites ..."
  sudo yum install -y zlib-devel curl-devel openssl-devel httpd-devel apr-devel apr-util-devel mysql-devel
  if [ $? -ne 0 ]; then
    print -e "  Prerequisites installation failed."
    exit 1
  fi
  print "  Installing bundler ..."
  gem install bundler || { print -e "  Failed to install bundler."; exit 1; }
  print "  Completed."
  print "  Which Redmine version do you want to install?"
  read ver
  print "  Downloading Redmine archive ..."
  curl -# -O "http://www.redmine.org/releases/redmine-$ver.tar.gz" || { print -e "  Failed to download Redmine archive."; exit 1; }
  print "  Completed."
  print "  Unpacking archive ..."
  tar xvzf "redmine-$ver.tar.gz" || { print -e "  Failed to unpack redmine archive."; exit 1; }
  print "  Completed."
  which mysql &> /dev/null || { print -e "  MySQL isn't installed. Installation failed."; exit 1; }
  print "  Installing redmine database ..."
  print "    Enter MySQL root password:"
  read rootPwd
  print "  Checking for existing redmine database ..."
  redmineScheme=$(mysql -u root -p$rootPwd -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'redmine'")
  if [ ! -z "$redmineScheme" ]; then
    print "    Removing existing redmine database ..."
    mysql -u root -p$rootPwd -e "drop database redmine" || { print -e "   Failed to drop redmine database."; exit 1; }
    print "    Completed."
  fi
  print "  Completed."
  print "  Checking for existing redmine db user account ..."
  redmineUser=$(mysql -u root -p$rootPwd -e "select user from mysql.user where user='redmine'")
  if [ ! -z "$redmineUser" ]; then
    print "      Revoking privileges from redmine db account ... "
    mysql -u root -p$rootPwd -e "revoke all privileges, grant option from 'redmine'@localhost" || { print -e "      Failed to revoke redmine privileges."; exit 1; }
    print "      Completed."
    print "      Deleting existing redmine db account ..."
    mysql -u root -p$rootPwd -e "drop user 'redmine'@localhost" || { print -e "  Failed to delete existing redmine user db account."; exit 1; }
    print "      Completed."
    print "      Flashing privileges ..."
    mysql -u root -p$rootPwd -e "flush privileges"
    print "      Completed."
  fi
  print "  Completed."
  print "    Creating redmine database ..."
  mysql -u root -p$rootPwd -e "create database redmine character set utf8;" || { print -e "    Failed to created redmine database."; exit 1; }
  print "    Completed."
  print "    Creating redmine db user account ..."
  print "    Enter redmine user password: "
  read redminePwd
  mysql -u root -p$rootPwd -e "create user 'redmine'@'localhost' identified by '$redminePwd';" || { print -e "    Failed to create redmine db user."; exit 1;}
  print "    Completed."
  print "    Granting all privileges to on redmine.* to redmine db user ..."
  mysql -u root -p$rootPwd -e "grant all privileges on redmine.* to 'redmine'@'localhost';" || { print -e "   Failed to grant all privileges to redmine user."; exit 1; }
  print "    Completed."
  print "  Completed."
  print "  Moving to redmine-$ver/config folder ..."
  cd redmine-$ver/config || { print -e "  Failed to changed current directory to redmine-$ver/config."; exit 1; }
  print "  Completed."
  print "  Updating redmine database.yml file ..."
  print "    Copying database.yml.example to database.yml ..."
  cp database.yml.example database.yml || { print -e "    Failed to copy database.yml.example to database.yml."; exit 1; }
  print "    Completed."
  print "    Updating database settings ..."
  awk -v pwd="$rootPwd" 'BEGIN { ORS=RS="\n\n" ; OFS=FS="\n" } ; {\
    if ($NF != "") {\
      if ($1 ~ /^production/) {\
        for (i = 1; i <= NF; i++) {\
          if ($i ~ /password/) $i= "  password: " pwd; printf "%s\n", $i\
        }\
        printf "\n"\
      } else print\
    }\
  }' < database.yml.example > database.yml.tmp
  if [ $? -ne 0 ]; then
    print -e "    Failed to update database settings."
    exit 1
  fi
  print "    Copying database.yml.tmp to database.yml"
  cp database.yml.tmp database.yml || { print -e "    Failed to copy database.yml.tmp to database.yml."; exit 1; }
  print "    Completed."
  print "    Removing database.yml.tmp file ..."
  rm database.yml.tmp || { print -e "    Failed to remove database.yml.tmp file."; }
  print "    Completed."
  print "  Completed."
  print "  Installing ImageMagick ..."
  sudo yum install -y ImageMagick ImageMagick-devel || { print -e "  Failed to install ImageMagick."; exit 1; }
  print "  Completed."
  print "  Installing redmine's required Ruby gems ..."
  bundler install || {  print -e "  Failed to install redmine's required Ruby gems."; exit 1; }
  print "  Completed."
  print "  Ganerate secret token ..."
  rake generate_secret_token || { print -e "  Failed to generate secret token."; exit 1; }
  print "  Completed."
  print "  Migrating the database model ..."
  RAILS_ENV=production rake db:migrate || { print -e "  Failed to migrate the database model."; exit 1; }
  print "  Completed."
  print "  Loading default data ..."
  RAILS_ENV=production rake redmine:load_default_data || { print -e "  Failed to load default data."; exit 1; }
  print "  Completed."
}

install_gateone() {
  print "Installing gateone ..."
  print "  Installing prerequisites ..."
  packages=("git" "gcc" "python-devel" "httpd")
  install_packages ${packages[@]} || { print "  Failed to install all prerequisities. Installation aborted."; exit 1; }
}

install_jenkins() {
  print "Installing Jenkins ..."
  yum list installed | grep jenkins > /dev/null
  if [ $? -eq 0 ]; then
    print "There is a previous Jenkins installation do you want to remove it (y/n)?" 2
    local response='y'
    read response
    if [ $response -eq 'n' ]; then
      print "Aborting Jenkins installation."; 
      exit; 
    else
      sudo yum remove jenkins || { print -e "Failed to remove previous Jenkins installation. Installation aborted." 2; }
    fi
  fi
  local jenkinsVersion=-1;
  print "Jenkins version to install?" 2
  read $jenkinsVersion
  print "Checking if Jenkins repo exists ..."
  readlink -e /etc/yum.repo.d/jenkins.repo > /dev/null
  if [ $? -ne 0 ]; then
    print "Jenkins repo does not exist, creating it ..." 2
    sudo -E curl -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
    if [ $? -ne 0 ]; then
      print -e "Failed to create Jenkins repo. Installation aborted." 2
      exit 1
    fi
    print "Completed." 2
    print "Downloading Jenkins repo public key ..." 2
    local filename="jenkins-ci.org.key"
    curl -sO "http://pkg.jenkins-ci.org/redhat/$filename" || { print -e "Failed to download Jenkins repo public key. Installation Aborted." 2; exit 1; }
    print "Completed" 2
    publicKeyVersion=$(gpg "$filename" | sed -rn 's/^pub\s+[^/]+\/([A-Z0-9]+).*/\1/p')
    rpm -q gpg-pubkey | grep -iqs "gpg-pubkey-$publicKeykVersion"
    if [ $? -ne 0 ]; then
      print "Importing Jenkins public key ..."
      sudo rpm --import "$filename" || { print -e "Failed to import Jenkins public key. Installation aborted." 2; exit 1; }
      print "Completed." 2
    fi
    print "Installing Jenkins version $jenkinsVersion ..."
    sudo yum install "jenkins-$jenkinsVersion" || { print -e "Failed to install Jenkins v$jenkinsVersion."; exit 1; }
    print "Completed."
  fi
}

trap tofl EXIT

tonl
print_usage
read_option
install
tofl

