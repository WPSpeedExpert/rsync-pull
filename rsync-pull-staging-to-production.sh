#!/bin/bash
# =========================================================================== #
# Description:        Rsync staging to production | Cloudpanel to Cloudpanel.
# Details:            Rsync Pull, the script will run from the production server.
# Made for:           Linux, Cloudpanel (Debian & Ubuntu).
# Requirements:       Cloudpanel | ssh-keygen | ssh-copy-id root@127.0.0.1 (replace IP)
# Author:             WP Speed Expert
# Author URI:         https://wpspeedexpert.com
# Version:            3.5
# GitHub:             https://github.com/WPSpeedExpert/rsync-pull/
# Make executable:    chmod +x rsync-pull-staging-to-production.sh
# Crontab @weekly:    0 0 * * MON /home/${siteUser}/rsync-pull-staging-to-production.sh 2>&1
# =========================================================================== #
#
# Variables: Source | Production
domainName=("domainName.com")
siteUser=("site-user")
# Variables: Destination | Staging #
staging_domainName=("staging.domainName.com")
staging_siteUser=("staging_siteUser")
#
remote_server_ssh=("root@0.0.0.0")
table_Prefix=("wp_") # wp_
# That's all, stop editing! #
#
# Destination | Production #
databaseName=${siteUser} # change if different to siteuser
databaseUserName=${siteUser} # change if different to siteuser
websitePath=("/home/${siteUser}/htdocs/${domainName}")
scriptPath=("/home/${siteUser}")
databaseUserPassword=$(sed -n 's/^password\s*=\s*"\(.*\)".*/\1/p' "${scriptPath}/my.cnf")
# Source | Staging #
staging_databaseName=${staging_siteUser} # change if different to siteuser
staging_databaseUserName=${staging_siteUser} # change if different to siteuser
staging_websitePath=("/home/${staging_siteUser}/htdocs/${staging_domainName}")
staging_scriptPath=("/home/${staging_siteUser}")
#
LogFile=("${scriptPath}/rsync-pull-staging-to-production.log")
#

# Empty the log file
truncate -s 0 ${LogFile}

# Log the date and time
echo "[+] NOTICE: Start script: $(date -u)" 2>&1 | tee -a ${LogFile}

# Check for WP directory & wp-config.php
if [ ! -d ${websitePath} ]; then
  echo "[+] ERROR: Directory ${websitePath} does not exist"
  exit
fi 2>&1 | tee -a ${LogFile}

if [ ! -f ${websitePath}/wp-config.php ]; then
  echo "[+] ERROR: No wp-config.php in ${websitePath}"
  echo "[+] WARNING: Creating wp-config.php in ${websitePath}"
  # Copy the content of WP Salts page
  WPsalts=$(wget https://api.wordpress.org/secret-key/1.1/salt/ -q -O -)
  cat <<EOF > ${websitePath}/wp-config.php
<?php
/**
  * The base configuration for WordPress
  *
  * The wp-config.php creation script uses this file during the installation.
  * You don't have to use the web site, you can copy this file to "wp-config.php"
  * and fill in the values.
  *
  * This file contains the following configurations:
  *
  * * Database settings
  * * Secret keys
  * * Database table prefix
  * * Localized language
  * * ABSPATH
  *
  * @link https://wordpress.org/support/article/editing-wp-config-php/
  *
  * @package WordPress
*/
// define( 'WP_AUTO_UPDATE_CORE', false );

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', "${databaseName}" );

/** Database username */
define( 'DB_USER', "${databaseUserName}" );

/** Database password */
define( 'DB_PASSWORD', "${databaseUserPassword}" );

/** Database hostname */
define( 'DB_HOST', "localhost" );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
  * Authentication unique keys and salts.
  *
  * Change these to different unique phrases! You can generate these using
  * the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}.
  *
  * You can change these at any point in time to invalidate all existing cookies.
  * This will force all users to have to log in again.
  *
  * @since 2.6.0
*/
${WPsalts}
define('WP_CACHE_KEY_SALT','${domainName}');
/**#@-*/

/**
 * WordPress database table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
\$table_prefix  = '${table_Prefix}';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://wordpress.org/support/article/debugging-in-wordpress/
 */
define( 'WP_DEBUG', false );

/* Add any custom values between this line and the "stop editing" line. */
define( 'FS_METHOD', 'direct' );
define( 'WP_DEBUG_DISPLAY', false );
define( 'WP_DEBUG_LOG', true );
define( 'CONCATENATE_SCRIPTS', false );
define( 'AUTOSAVE_INTERVAL', 600 );
define( 'WP_POST_REVISIONS', 5 );
define( 'EMPTY_TRASH_DAYS', 21 );
/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', dirname(__FILE__) . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
EOF
  echo "[+] SUCCESS: Created wp-config.php in ${websitePath}"
  exit
fi 2>&1 | tee -a ${LogFile}

if [ -f ${websitePath}/wp-config.php ]; then
  echo "[+] SUCCESS: Found wp-config.php in ${websitePath}"
fi 2>&1 | tee -a ${LogFile}

# Clean and remove destination website files (except for the wp-config.php & .user.ini)
# Use this to exclude the uploads folder: ! -regex '^'${staging_websitePath}'/wp-content/uploads\(/.*\)?'
echo "[+] NOTICE: Clean up the destination website files: ${websitePath}" 2>&1 | tee -a ${LogFile}
find ${websitePath}/ -mindepth 1 ! -regex '^'${websitePath}'/wp-config.php' ! -regex '^'${websitePath}'/.user.ini' -delete

# Export the remote MySQL database
echo "[+] NOTICE: Export the remote database: ${staging_databaseName}" 2>&1 | tee -a ${LogFile}
# Use Cloudpanel CLI
# clpctl db:export --databaseName=${staging_databaseName} --file=${staging_scriptPath}/tmp/${staging_databaseName}.sql.gz 2>&1 | tee -a ${LogFile}
ssh ${remote_server_ssh} "clpctl db:export --databaseName=${staging_databaseName} --file=${staging_scriptPath}/tmp/${staging_databaseName}.sql.gz" 2>&1 | tee -a ${LogFile}

# Sync the database
echo "[+] NOTICE: Synching the database: ${staging_databaseName}.sql.gz" 2>&1 | tee -a ${LogFile}
# rsync -azP ${staging_scriptPath}/tmp/${staging_databaseName}.sql.gz ${scriptPath}/tmp 2>&1 | tee -a ${LogFile}
rsync -azP ${remote_server_ssh}:${staging_scriptPath}/tmp/${staging_databaseName}.sql.gz ${scriptPath}/tmp 2>&1 | tee -a ${LogFile}

# Clean up the remote database export file
echo "[+] NOTICE: Clean up the remote database export file: ${databaseName}" 2>&1 | tee -a ${LogFile}
# rm ${staging_scriptPath}/tmp/${staging_databaseName}.sql.gz
ssh ${remote_server_ssh} "rm ${staging_scriptPath}/tmp/${staging_databaseName}.sql.gz" 2>&1 | tee -a ${LogFile}

# Delete the production database
# echo "[+] WARNING: Deleting the database: ${databaseName}" 2>&1 | tee -a ${LogFile}
# clpctl db:delete --databaseName=${databaseName} --force 2>&1 | tee -a ${LogFile}

# Create/add a new production database
# echo "[+] NOTICE: Add the database: ${databaseName}" 2>&1 | tee -a ${LogFile}
# clpctl db:add --domainName=${domainName} --databaseName=${databaseName} --databaseUserName=${databaseUserName} --databaseUserPassword=''${databaseUserPassword}'' 2>&1 | tee -a ${LogFile}

# Drop all database tables (clean up)
echo "[+] NOTICE: Drop all database tables ..." 2>&1 | tee -a ${LogFile}
#
# Create a variable with the command to list all tables
tables=$(mysql --defaults-extra-file=${scriptPath}/my.cnf -Nse 'SHOW TABLES' ${databaseName})
#
# Loop through the tables and drop each one
for table in $tables; do
    echo "[+] NOTICE: Dropping $table from ${databaseName}." 2>&1 | tee -a ${LogFile}
    mysql --defaults-extra-file=${scriptPath}/my.cnf  -e "DROP TABLE $table" ${databaseName}
done
    echo "[+] SUCCESS: All tables dropped from ${databaseName}." 2>&1 | tee -a ${LogFile}

# Import the MySQL database:
echo "[+] NOTICE: Import the MySQL database: ${staging_databaseName}.sql.gz in to ${databaseName}" 2>&1 | tee -a ${LogFile}
# Use Cloudpanel CLI
clpctl db:import --databaseName=${databaseName} --file=${scriptPath}/tmp/${staging_databaseName}.sql.gz 2>&1 | tee -a ${LogFile}

# Cleanup the mySQL database export file
echo "[+] NOTICE: Clean up the database export file: ${scriptPath}/tmp/${staging_databaseName}.sql.gz" 2>&1 | tee -a ${LogFile}
rm ${scriptPath}/tmp/${staging_databaseName}.sql.gz

# Search and replace URL in the database
echo "[+] NOTICE: Search and replace URL in the database: ${databaseName}." 2>&1 | tee -a ${LogFile}
mysql --defaults-extra-file=${scriptPath}/my.cnf -D ${databaseName} -e "
UPDATE ${table_Prefix}options SET option_value = REPLACE (option_value, 'https://${staging_domainName}', 'https://${domainName}') WHERE option_name = 'home' OR option_name = 'siteurl';
UPDATE ${table_Prefix}posts SET post_content = REPLACE (post_content, 'https://${staging_domainName}', 'https://${domainName}');
UPDATE ${table_Prefix}posts SET post_excerpt = REPLACE (post_excerpt, 'https://${staging_domainName}', 'https://${domainName}');
UPDATE ${table_Prefix}postmeta SET meta_value = REPLACE (meta_value, 'https://${staging_domainName}', 'https://${domainName}');
UPDATE ${table_Prefix}termmeta SET meta_value = REPLACE (meta_value, 'https://${staging_domainName}', 'https://${domainName}');
UPDATE ${table_Prefix}comments SET comment_content = REPLACE (comment_content, 'https://${staging_domainName}', 'https://${domainName}');
UPDATE ${table_Prefix}comments SET comment_author_url = REPLACE (comment_author_url, 'https://${staging_domainName}','https://${domainName}');
UPDATE ${table_Prefix}posts SET guid = REPLACE (guid, 'https://${staging_domainName}', 'https://${domainName}') WHERE post_type = 'attachment';
" 2>&1 | tee -a ${LogFile}

# Disable: Discourage search engines from indexing this website
echo "[+] NOTICE: Disable discourage search engines from indexing this website." 2>&1 | tee -a ${LogFile}
mysql --defaults-extra-file=${scriptPath}/my.cnf -D ${databaseName} -e "
UPDATE ${table_Prefix}options SET option_value = replace (option_value, '0', '1') WHERE option_name = 'blog_public';
" 2>&1 | tee -a ${LogFile}

# Check if query was_successful
echo "[+] NOTICE: Check if query was_successful." 2>&1 | tee -a ${LogFile}
query=$(mysql --defaults-extra-file=${scriptPath}/my.cnf -D ${databaseName} -se "SELECT option_value FROM ${table_Prefix}options WHERE option_name = 'siteurl';")
echo "[+] SUCCESS: Siteurl = $query." 2>&1 | tee -a ${LogFile}

# Rsync website files (pull)
echo "[+] NOTICE: Start Rsync pull" 2>&1 | tee -a ${LogFile}
# rsync -azP --update --delete --no-perms --no-owner --no-group --no-times --exclude 'wp-content/cache/*' --exclude 'wp-content/backups-dup-pro/*' --exclude 'wp-config.php' --exclude '.user.ini' ${staging_websitePath}/ ${websitePath}
rsync -azP --update --delete --no-perms --no-owner --no-group --no-times --exclude 'wp-content/cache/*' --exclude 'wp-content/backups-dup-pro/*' --exclude 'wp-config.php' --exclude '.user.ini' ${remote_server_ssh}:${staging_websitePath}/ ${websitePath}

# Set correct ownership
echo "[+] NOTICE: Set correct ownership." 2>&1 | tee -a ${LogFile}
chown -Rf ${siteUser}:${siteUser} ${websitePath}

# Set correct file permissions for folders
echo "[+] NOTICE: Set correct file permissions for folders." 2>&1 | tee -a ${LogFile}
chmod 00755 -R ${websitePath}

# Set correct file permissions for files
echo "[+] NOTICE: Set correct file permissions for files." 2>&1 | tee -a ${LogFile}
find ${websitePath}/ -type f -print0 | xargs -0 chmod 00644

# Flush & restart Redis
echo "[+] NOTICE: Flush and restart Redis." 2>&1 | tee -a ${LogFile}
redis-cli FLUSHALL
sudo systemctl restart redis-server

# End of the script
echo "[+] NOTICE: End of script: $(date -u)" 2>&1 | tee -a ${LogFile}
exit 0
