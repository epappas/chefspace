#!/bin/sh
#
# Copyright 2015 Vibrant Media Ltd
#
# Refer to chefspace README.md
#
# Contributors:
# - Evangelos Pappas
#
# Enjoy!

DRY_MODE=0
LOCAL_MODE=0
CHEFSPACE_LOCAL_PATH='.'
CHEFSPACE_TARGET_PATH=/opt/chef/chefspace
SSH_ARGS='-t'
SSH_ACC=''
SSH_HOST=''
USER='root'
GROUP='root'
SUDO="sudo -i -u $USER"
SUDO2="sudo -u $USER"
export USE_SYSTEM_GECODE=1

set -e

execute(){
  if [ $DRY_MODE -ne 0 ]; then
      echo "$@"
  else
      echo "----> $@"
      $@
  fi
}

do_ssh() {
  execute ssh $SSH_ARGS $SSH_ACC@$SSH_HOST "$@"
}

safe_do(){
  if [ $LOCAL_MODE -ne 0 ]; then
    execute $SUDO $@
  else
    do_ssh $SUDO $@
  fi
}

unsafe_do(){
  if [ $LOCAL_MODE -ne 0 ]; then
    execute $SUDO2 $@
  else
    do_ssh $SUDO2 $@
  fi
}

safe_f_stat(){
  if [ $LOCAL_MODE -ne 0 ]; then
    echo $(stat $1 2>&1 >/dev/null)
  else
    echo $(safe_do stat $1 \> /dev/null 2\>\&1)
  fi
}

safe_transfer(){
  if [ $LOCAL_MODE -ne 0 ]; then
    execute $SUDO2 cp -rf $@
    execute $SUDO chown -R $USER:$GROUP $2
  else
    execute scp -r $1 $SSH_ACC@$SSH_HOST:$2
    do_ssh $SUDO chown -R $USER:$GROUP $2
  fi
}

check_conn(){
  if [ $LOCAL_MODE -ne 0 ]; then
    echo 'ok'
  else
    echo $(execute ssh -q $SSH_ACC@$SSH_HOST exit && echo 'ok')
  fi
}

commend(){
  if [ $DRY_MODE -ne 0 ]; then
      echo "# " $@
  else
      echo $@
  fi
}

install_deps(){
  safe_do apt-get -y update
  # safe_do apt-get -y upgrade
  safe_do apt-get -y install g++ curl git build-essential \
    ruby-dev ruby1.9.1-full libxslt-dev libxml2-dev \
    ruby-dep-selector libqtcore4 libqtgui4 libqt4-dev libboost-dev \
    libgecode-dev
}

install_chef(){
  if [ ! -z "$(safe_f_stat /opt/chefdk)" ]; then
    # url="https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chefdk_0.6.0-1_amd64.deb"
    url="https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chefdk_0.6.2-1_amd64.deb"
    pkg="/tmp/`basename \`echo $url\``"

    safe_do wget "$url" -O "$pkg"

    safe_do dpkg -i --force-overwrite "$pkg"
    safe_do apt-get -f install
    safe_do rm -f "$pkg"
  fi
}

install_gem_deps(){
  safe_do /opt/chefdk/embedded/bin/gem install --no-rdoc --no-ri ruby-shadow knife-solo foodcritic
  if [ ! -z "$(safe_f_stat  /usr/local/bin/berks)" ]; then
    safe_do ln -s /opt/chefdk/embedded/bin/berks /usr/local/bin
  fi
}

install_chefspace(){
  safe_do mkdir -p $CHEFSPACE_TARGET_PATH
  safe_transfer $CHEFSPACE_LOCAL_PATH $CHEFSPACE_TARGET_PATH
  unsafe_do /usr/local/bin/berks vendor $CHEFSPACE_TARGET_PATH/cookbooks
}

run_chefspace(){
  unsafe_do chef-client -c $CHEFSPACE_TARGET_PATH/.chef/client.rb -j $CHEFSPACE_TARGET_PATH/nodes/server.json
}

run_main(){
  install_deps
  install_chef
  install_gem_deps
  install_chefspace
  run_chefspace
}

if [ $# -eq 0 ]; then
  exit 0
fi

if [ ! -z "$(echo $@ | grep -e "--dry")" ]; then
  shift
  DRY_MODE=1
fi

if [ ! -z "$(echo $@ | grep -e "--local")" ]; then
  shift
  LOCAL_MODE=1
fi

SSH_ACC=$1
SSH_HOST=$2
SSH_ARGS=$3

run_main