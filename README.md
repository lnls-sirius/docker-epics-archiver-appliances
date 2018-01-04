# Docker images for the EPICS Archiver Appliances

Docker containers holding the EPICS archiver appliances.

## Building

1) Execute `build-docker-generic-appliance.sh` to build the base image for all the containers which will hold the appliances.
2) Change the working directory to `docker-appliance-images` and execute `build-docker-appliance-images.sh`. It will build 4 different images, one for each appliance. Before doing that, you'll need to 
change `setup-appliance.sh` up with your LDAP connection settings. The following command changes the servlet authentication preferences and must be modified with your server settings.

```
# Appends new realm
xmlstarlet ed -L -s '/Server/Service/Engine/Host' -t elem -n "Realm" \
                 -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionURL" -v "ldap://ad1.abtlus.org.br:389" \
                 -i '/Server/Service/Engine/Host/Realm' -t attr -n "alternativeURL" -v "ldap://ad2.abtlus.org.br:389" \
                 -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSearch" -v "(sAMAccountName={0})" \
                 -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSubtree" -v "true" \
                 -i '/Server/Service/Engine/Host/Realm' -t attr -n "userBase" -v "OU=LNLS,DC=abtlus,DC=org,DC=br" \
                 -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionName" -v "${CONNECTION_NAME}" \
                 -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionPassword" -v "${CONNECTION_PASSWORD}" \
                 -i '/Server/Service/Engine/Host/Realm' -t attr -n "className" -v "org.apache.catalina.realm.JNDIRealm" \
                 ${CATALINA_HOME}/conf/server.xml

```
Besides the LDAP settings, you must edit the following command with your certificate's right password (`PASSWORD`).

```
# Imports certificate into trusted keystore
keytool -import -alias tomcat -trustcacerts -storepass ${CERTIFICATE_PASSWORD} -noprompt -keystore $JAVA_HOME/lib/security/cacerts -file ${APPLIANCE_FOLDER}/build/cert/archiver-mgmt.crt
```

## Running

Change to `docker-appliance-images/` and execute `run-appliance-images.sh` to start all appliances. This script should be used only during development. For production, use these images with Docker Compose, Swarm or Kubernetes, according to this [project](https://github.com/lnls-sirius/docker-epics-archiver-composed). Enjoy!

## Dockerhub

All images described by this project were pushed into [this Dockerhub repo](https://hub.docker.com/u/lnlscon/).
