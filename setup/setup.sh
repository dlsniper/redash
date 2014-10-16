#!/bin/bash

# User defined variables are here
REDASH_VERSION='0.4.0+b568'
REDASH_BASE_PATH='/opt/redash'

PSQL_HOST=''
PSQL_USER=''
PSQL_DB=''

NGINX_PATH='/etc/nginx'


###############################################################################
# Automated part starts from here
# PLEASE DON'T MODIFY UNLESS YOU REALLY KNOW WHAT YOU ARE DOING
# BE WARNED, HERE BE DRAGONS
###############################################################################

function pause(){
   read -p "$* Press [ENTER] to continue..."
}

pause "Please make sure that you have your connection configuration under ${HOME}/.pgpass for database ${PSQL_HOST} user ${PSQL_USER}."
exit 0

REDASH_TARBALL=/tmp/redash.${REDASH_VERSION}.tar.gz
REDASH_VERSION_DIR=${REDASH_BASE_PATH}/${REDASH_VERSION}
REDASH_CURRENT_DIR=${REDASH_BASE_PATH}/current
SETUP_SCRIPT_DIR=$(dirname $(readlink /proc/$$/fd/255))

# Install dependencies
sudo apt-get update
sudo apt-get install -y postgresql-client python-pip curl python-dev

# Crease our re:dash user
sudo adduser --system --no-create-home --disabled-login --gecos "" redash

# Ensure we have the base path for our setup
sudo mkdir -p ${REDASH_BASE_PATH}
sudo mkdir ${REDASH_VERSION_DIR}
sudo chown -R redash /opt/redash

wget -O ${REDASH_TARBALL} https://github.com/EverythingMe/redash/releases/download/v${REDASH_VERSION}/redash."${REDASH_VERSION/\+/.}".tar.gz

sudo -u redash tar -C ${REDASH_VERSION_DIR} -xvf ${REDASH_TARBALL}
sudo -u redash ln -nfs ${REDASH_VERSION_DIR} ${REDASH_CURRENT_DIR}

cd ${REDASH_CURRENT_DIR}

sudo pip install -r requirements.txt
sudo pip install gunicorn

sudo -u redash cp ${SETUP_SCRIPT_DIR}/.env ${REDASH_BASE_PATH}/.env

pause "Please edit ${REDASH_CURRENT_DIR}/.env to ensure setup can continue."

psql -h ${PSQL_HOST} --user ${PSQL_USER} ${PSQL_DB} -tAc "SELECT 1 FROM pg_roles WHERE rolname='redash'" | grep -q 1
if [ $? -ne 0 ]; then
    sudo -u createuser -h ${PSQL_HOST} --user ${PSQL_USER} redash --no-superuser --no-createdb --no-createrole
	sudo -u createdb -h ${PSQL_HOST} --user ${PSQL_USER} redash --owner=redash

	cd ${REDASH_CURRENT_DIR}
	sudo -u redash bin/run ./manage.py database create_tables
fi

sudo cp ${SETUP_SCRIPT_DIR}/redash_updater.conf /etc/init/redash_updater.conf
sudo ${SETUP_SCRIPT_DIR}/redash_web.conf /etc/init/redash_web.conf

sudo start redash_web
sudo start redash_updater

sudo cp ${SETUP_SCRIPT_DIR}/redash ${NGINX_PATH}/sites-available/redash
sudo ln -nfs ${NGINX_PATH}/sites-available/redash ${NGINX_PATH}/sites-enabled/redash
sudo service nginx restart
