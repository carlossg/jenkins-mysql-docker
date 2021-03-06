#!/bin/bash

echo "Starting Jenkins"
/usr/local/bin/jenkins.sh &

DB_HOSTNAME=$MYSQL_PORT_3306_TCP_ADDR
DB_PORT=$MYSQL_PORT_3306_TCP_PORT
DB_DATABASE=jenkins
DB_USER=jenkins
DB_PASSWORD=$JENKINS_DB_PASSWORD

echo "Creating MySQL database"

MYSQL_CONFIG=/var/jenkins_home/.mysql

cat << EOF > $MYSQL_CONFIG
[client]
host=$DB_HOSTNAME
port=$DB_PORT
user=root
password=$MYSQL_ENV_MYSQL_ROOT_PASSWORD
EOF

cat << EOF | mysql --defaults-extra-file=$MYSQL_CONFIG
CREATE DATABASE IF NOT EXISTS $DB_DATABASE;

GRANT ALL PRIVILEGES ON $DB_DATABASE.* 
TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD' 
WITH GRANT OPTION;
EOF

rm -f $MYSQL_CONFIG


while ! curl -vLo /var/jenkins_home/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar 2>&1 | grep "Content-Type: application/java-archive" > /dev/null
do
  echo "Waiting for Jenkins to serve jenkins-cli"
  sleep 2
done


echo "Configuring Jenkins for MySQL"

cat << EOF | java -jar /var/jenkins_home/jenkins-cli.jar -s http://localhost:8080/ groovy =

import hudson.model.*;
import hudson.util.*;
import jenkins.model.*;
import org.jenkinsci.plugins.database.*;
import org.jenkinsci.plugins.database.mysql.*;

//db = hudson.model.Hudson.instance.pluginManager.getPlugin("database")

config = Jenkins.getInstance().getDescriptor( GlobalDatabaseConfiguration.class )
db = new MySQLDatabase("$DB_HOSTNAME:$DB_PORT", "$DB_DATABASE", "$DB_USER", Secret.fromString("$DB_PASSWORD"), "")
config.setDatabase(db)

println "Jenkins configured to use MySQL at $DB_USER@$DB_HOSTNAME:$DB_PORT/$DB_DATABASE"

EOF

wait
