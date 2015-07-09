#!/bin/bash

# This script migrates CiviCRM from a Drupal site to a WordPress site. It assumes that there are three sites on the same box:
# 1. A WordPress staging site with no meaningful CiviCRM database
# 2. A Drupal staging site with meaningful CiviCRM data
# 3. A production site to which the stage CMS and stage CRM will be migrated

CALLPATH=`dirname "$0"`
ABS_CALLPATH="`( cd \"${CALLPATH}\" && pwd -P)`"

shopt -s dotglob

source ${ABS_CALLPATH}/conf/migrate.conf

echo "Clearing path for production site..."

echo "Dropping files..."
rm -rf ${PROD_WEBROOT}/*

echo "Dropping databases..."
echo "DROP DATABASE $PROD_DB_CMS; CREATE DATABASE ${PROD_DB_CMS};" | mysql
echo "DROP DATABASE $PROD_DB_CRM; CREATE DATABASE ${PROD_DB_CRM};" | mysql

echo "Copying files from staging WP site..."
cp -a ${STAGING_WEBROOT}/* ${PROD_WEBROOT}

echo "Unzipping CiviCRM for WP..."
SRC_ARCHIVE=civicrm-${CIVICRM_VER}-wordpress.zip

# download or reuse CiviCRM
mkdir -p ${ABS_CALLPATH}/src/
if [[ ! ( -f "${ABS_CALLPATH}/src/${SRC_ARCHIVE}" ) ]]; then
  echo "Please wait while CiviCRM is downloaded..."
  wget -P ${ABS_CALLPATH}/src/ "https://download.civicrm.org/${SRC_ARCHIVE}"
fi

if [[ ! ( -f "${ABS_CALLPATH}/src/${SRC_ARCHIVE}" ) ]]; then
  echo "${SRC_ARCHIVE} was not found and could not be downloaded" 1>&2
  exit 1
fi

rm -rf ${PROD_WEBROOT}/wp-content/plugins/civicrm
unzip -q ${ABS_CALLPATH}/src/${SRC_ARCHIVE} -d ${PROD_WEBROOT}/wp-content/plugins

echo "Setting production configs..."
cp ${ABS_CALLPATH}/conf/wp-config.php ${PROD_WEBROOT}
cp ${ABS_CALLPATH}/conf/civicrm.settings.php ${PROD_WEBROOT}/wp-content/plugins/civicrm

echo "Copying WP database..."
mysqldump ${STAGING_DB_CMS} | mysql ${PROD_DB_CMS}

echo "Replacing hardcoded URLs in the database..."
chmod +x ${SRDB}
php ${SRDB} -h localhost -u FIXME -n ${PROD_DB_CMS} -s "www.${STAGING_URL}" -p FIXME -r "www.${PROD_URL}"
php ${SRDB} -h localhost -u FIXME -n ${PROD_DB_CMS} -s ${STAGING_URL} -p FIXME -r "www.${PROD_URL}"

echo "Copying CiviCRM database..."
# the --defaults-file flag and the pipe through sed are to work around Siteground's permission restrictions (I think we must be used to having SUPER privileges)...
mysqldump ${STAGING_DB_CRM} | sed 's#DEFINER=`FIXME_dev`#DEFINER=`FIXME_prod`#' | mysql --defaults-file=${ABS_CALLPATH}/conf/.my.prod.cnf ${PROD_DB_CRM}

echo "Updating uf_match table..."
mysql < ${ABS_CALLPATH}/update_uf_match.sql

echo "To complete the process, visit the following URLs:"
echo "http://${PROD_URL}/wp-admin/admin.php?page=CiviCRM&q=civicrm/admin/setting/updateConfigBackend&reset=1"
echo "http://${PROD_URL}/wp-admin/admin.php?page=CiviCRM&q=civicrm/admin/setting/url&reset=1"
echo "http://${PROD_URL}/wp-admin/admin.php?page=CiviCRM&q=civicrm/menu/rebuild&reset=1"
echo "http://${PROD_URL}/wp-admin/admin.php?page=CiviCRM&q=civicrm/admin/setting/uf&reset=1"

shopt -u dotglob
