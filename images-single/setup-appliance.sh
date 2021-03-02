#!/bin/bash
set -a
set -e
set -x

function checkout_archiver_branch {
    if [ "${USE_AUTHENTICATION}" = true ]; then
        GITHUB_APPLIANCES_BRANCH=${GITHUB_APPLIANCES_BRANCH:-ldap-login}
    else
        GITHUB_APPLIANCES_BRANCH=${GITHUB_APPLIANCES_BRANCH:-master}
    fi

    (
        cd ${GITHUB_REPOSITORY_FOLDER}
        git config user.email "controle@lnls.br"
        git config user.name "Controls Group"
        git fetch origin ${GITHUB_APPLIANCES_BRANCH}
        git checkout ${GITHUB_APPLIANCES_BRANCH}
    )
}

function setup_mysql_connection {

    if [ -z "$MYSQL_SQL_ADDRESS" ]; then
        MYSQL_SQL_ADDRESS=$(getent hosts epics-archiver-mysql-db | awk '{ print $1 }')
        echo "Using default MYSQL_SQL_ADDRESS=${MYSQL_SQL_ADDRESS}"
    fi

    if [ -z "$MYSQL_PORT" ]; then
        MYSQL_PORT=3306
        echo "Using default MYSQL_PORT=${MYSQL_PORT}"
    fi

    set -u

    # setup database connection
    xmlstarlet ed --inplace \
        --update "/Context/Resource[@name='jdbc/archappl']/@username"\
        --value "${MYSQL_USER}" ${CATALINA_HOME}/conf/context.xml
    xmlstarlet ed --inplace \
        --update "/Context/Resource[@name='jdbc/archappl']/@password"\
        --value "${MYSQL_PASSWORD}" ${CATALINA_HOME}/conf/context.xml
    xmlstarlet ed --inplace \
        --update "/Context/Resource[@name='jdbc/archappl']/@url" \
        --value "jdbc:mysql://${MYSQL_SQL_ADDRESS}:${MYSQL_PORT}/${MYSQL_DATABASE}" ${CATALINA_HOME}/conf/context.xml
}

function setup_ssl_certs {
    [[ ! -d ${APPLIANCE_CERTS_FOLDER} ]] && mkdir --verbose --parents ${APPLIANCE_CERTS_FOLDER}

    if [ ! -f ${APPLIANCE_CERTS_FOLDER}/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.keystore ]; then
        # Generates keystore
        keytool\
        -genkey\
        -alias tomcat\
        -keyalg RSA\
        -dname "CN=${IP_ADDRESS}, OU=GAS, O=CNPEM, L=Campinas, ST=SP, C=BR"\
        -storepass ${CERTIFICATE_PASSWORD}\
        -keypass ${CERTIFICATE_PASSWORD}\
        -keystore ${APPLIANCE_CERTS_FOLDER}/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.keystore\
        -validity 3650
    fi

    if [ ! -f ${APPLIANCE_CERTS_FOLDER}/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.crt ]; then
        # Generates certificate
        keytool\
        -exportcert\
        -keystore ${APPLIANCE_CERTS_FOLDER}/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.keystore\
        -alias tomcat\
        -storepass ${CERTIFICATE_PASSWORD}\
        -file ${APPLIANCE_CERTS_FOLDER}/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.crt
    fi

    # Imports certificate into trusted keystore
    for IDENTITY in $(xmlstarlet sel -t -v "/appliances/appliance/identity" ${ARCHAPPL_APPLIANCES}); do
        # In case of multiple appliances, loop until we have all required crts
        CRT_FILE=${APPLIANCE_CERTS_FOLDER}/${IDENTITY}-${APPLIANCE_UNIT}.crt
        while [ ! -f ${CRT_FILE} ]; do
            echo "CRT ${CRT_FILE} does not exists"
            sleep 2 # or less like 0.2
        done

        keytool \
            -import\
            -alias tomcat\
            -trustcacerts\
            -storepass ${CERTIFICATE_PASSWORD}\
            -noprompt\
            -keystore /usr/local/openjdk-15/lib/security/cacerts \
            -file ${CRT_FILE}
    done

    # Copies keystore to conf/
    cp --verbose ${APPLIANCE_CERTS_FOLDER}/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.keystore ${CATALINA_HOME}/conf/

    # Force HTTPS
    xmlstarlet ed -L \
        -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url"\
        -v "https://${IP_ADDRESS}:${APPLIANCE_PORT}/${APPLIANCE_UNIT}/bpl" ${ARCHAPPL_APPLIANCES}

    # Remove default connector port
    xmlstarlet ed -L -d "/Server/Service/Connector" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    # Appends new connector
    xmlstarlet ed -L -s "/Server/Service" -t elem -n "Connector" \
        -i "/Server/Service/Connector" -t attr -n "protocol" -v "org.apache.coyote.http11.Http11NioProtocol" \
        -i "/Server/Service/Connector" -t attr -n "port" -v "${APPLIANCE_PORT}" \
        -i "/Server/Service/Connector" -t attr -n "redirectPort" -v "8443" \
        -i "/Server/Service/Connector" -t attr -n "maxThreads" -v "150" \
        -i "/Server/Service/Connector" -t attr -n "SSLEnabled" -v "true" \
        -i "/Server/Service/Connector" -t attr -n "scheme" -v "https" \
        -i "/Server/Service/Connector" -t attr -n "secure" -v "true" \
        ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    xmlstarlet ed -L -s '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']' -t elem -n "SSLHostConfig" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    cp --verbose ${APPLIANCE_CERTS_FOLDER}/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.keystore ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf

    xmlstarlet ed -L \
        -s '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']/SSLHostConfig' -t elem -n "Certificate" \
        -i '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']/SSLHostConfig/Certificate' \
            -t attr -n "certificateKeystoreFile" -v "conf/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.keystore" \
        -i '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']/SSLHostConfig/Certificate' -t attr -n "type" -v "RSA" \
        ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
}

function setup_ldap_realm {
    # Appends new realm
    xmlstarlet ed -L -s '/Server/Service/Engine/Host' -t elem -n "Realm" \
        -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionURL" -v "${CONNECTION_URL}" \
        -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSearch" -v "${CONNECTION_USER_FILTER}" \
        -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSubtree" -v "true" \
        -i '/Server/Service/Engine/Host/Realm' -t attr -n "userBase" -v "${CONNECTION_USER_BASE}" \
        -i '/Server/Service/Engine/Host/Realm' -t attr -n "className" -v "org.apache.catalina.realm.JNDIRealm" \
        ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    if [ ! -z ${ALTERNATIVE_URL+x} ]; then
        xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "alternativeURL" -v "${ALTERNATIVE_URL}" \
            ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
    fi

    if [ ! -z ${CONNECTION_ROLE_BASE+x} ]; then
        xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "roleBase" -v "${CONNECTION_ROLE_BASE}" \
            -i '/Server/Service/Engine/Host/Realm' -t attr -n "roleSubtree" -v "true" \
            ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
    fi

    if [ ! -z ${CONNECTION_ROLE_NAME+x} ]; then
        xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "roleName" -v "${CONNECTION_ROLE_NAME}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
    fi

    if [ ! -z ${CONNECTION_ROLE_SEARCH+x} ]; then
        xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "roleSearch" -v "${CONNECTION_ROLE_SEARCH}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
    fi

    if [ ! -z ${CONNECTION_NAME+x} ]; then
        xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionName" -v "${CONNECTION_NAME}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
    fi

    if [ ! -z ${CONNECTION_PASSWORD+x} ]; then
        xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionPassword" -v "${CONNECTION_PASSWORD}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
    fi
}

function build_appliances {
    for APPLIANCE_UNIT in "mgmt" "engine" "retrieval" "etl"; do

        # Change wardest and dist properties in build.xml to ./
        xmlstarlet ed -L -u "/project/property[@name='wardest']/@location" -v "./" ${GITHUB_REPOSITORY_FOLDER}/build.xml
        xmlstarlet ed -L -u "/project/property[@name='dist']/@location" -v "./" ${GITHUB_REPOSITORY_FOLDER}/build.xml

        # Build only specific war file
        export TOMCAT_HOME=${CATALINA_HOME}
        (
            cd ${GITHUB_REPOSITORY_FOLDER}
            ant -quiet ${APPLIANCE_UNIT}_war | grep -v javadoc
        )

        mkdir --verbose ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}

        mv --verbose ${GITHUB_REPOSITORY_FOLDER}/${APPLIANCE_UNIT}.war ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}
        (
            cd ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}
            jar xf ${APPLIANCE_UNIT}.war
        )

        rm --verbose ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}/${APPLIANCE_UNIT}.war
    done
}

function update_appliance_config {
    set -x
    for APPLIANCE_UNIT in "mgmt" "engine" "retrieval" "etl"; do

        # Overwrite log4j settings if possible
        if [ -f "${APPLIANCE_FOLDER}/configuration/${APPLIANCE_UNIT}-log4j.properties" ]; then
            cp \
                --verbose\
                --force\
                "${APPLIANCE_FOLDER}/configuration/${APPLIANCE_UNIT}-log4j.properties"\
                ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}/WEB-INF/classes/log4j.properties
        fi

        # Do not allow external accesses in engine and etl appliances
        if [ "${APPLIANCE_UNIT}" = "engine" ] || [ "${APPLIANCE_UNIT}" = "etl" ]; then
            echo "Applying access restriction from external networks..."
            # Find a way to change allowed addresses with the internal network address
            # xmlstarlet ed -L -s '/Context' -t elem -n 'Valve' \
            #		  -i '/Context/Valve' -t attr -n 'className' -v 'org.apache.catalina.valves.RemoteAddrValve' \
            #                 -i '/Context/Valve' -t attr -n 'allow' -v '172\.17\.\d+\.\d+' \
            #                 ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/context.xml
        fi
    done
    set -x
}

RAND_SRV_PORT=${BASE_TOMCAT_SERVER_PORT:=1600}

# Before starting Tomcat service, change all addresses in lnls_appliances.xml.
# Get local ip address
IP_ADDRESS=$(hostname)

setup_mysql_connection

checkout_archiver_branch


for APPLIANCE_UNIT in "mgmt" "engine" "retrieval" "etl"; do

    APPLIANCE_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" ${ARCHAPPL_APPLIANCES} | sed "s/.*://" | sed "s/\/.*//")

    mkdir --verbose --parents ${CATALINA_HOME}/${APPLIANCE_UNIT}
    cp --verbose --recursive ${CATALINA_HOME}/conf ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf
    cp --verbose --recursive ${CATALINA_HOME}/webapps ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps

    mkdir --verbose --parents ${CATALINA_HOME}/${APPLIANCE_UNIT}/logs
    mkdir --verbose --parents ${CATALINA_HOME}/${APPLIANCE_UNIT}/temp
    mkdir --verbose --parents ${CATALINA_HOME}/${APPLIANCE_UNIT}/work

    # Unit's tomcat server port
    xmlstarlet ed -L -u '/Server/@port' -v ${RAND_SRV_PORT} ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    if [ "${APPLIANCE_UNIT}" = "engine" ] || [ "${APPLIANCE_UNIT}" = "etl" ] || [ "${APPLIANCE_UNIT}" = "retrieval" ]; then

        xmlstarlet ed -L -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" -v "http://${IP_ADDRESS}:${APPLIANCE_PORT}/${APPLIANCE_UNIT}/bpl" ${ARCHAPPL_APPLIANCES}

        if [ "${APPLIANCE_UNIT}" = "retrieval" ]; then
            xmlstarlet ed -L -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/data_retrieval_url" -v "http://${IP_ADDRESS}:${APPLIANCE_PORT}/${APPLIANCE_UNIT}" ${ARCHAPPL_APPLIANCES}
        fi

        # Appends new connector
        xmlstarlet ed -L -u "/Server/Service/Connector[@protocol='HTTP/1.1']/@port" -v ${APPLIANCE_PORT} ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

        # Remove every other connector entry from the conf/server.xml
        xmlstarlet ed -L -d "/Server/Service/Connector[@protocol!='HTTP/1.1']" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    elif [ "${APPLIANCE_UNIT}" = "mgmt" ]; then

        # Sets cluster inet port and host
        CLUSTER_INET_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/cluster_inetport" /opt/epics-archiver-appliances/configuration/lnls_appliances.xml | awk -F ':' '{print $2'})
        xmlstarlet ed -L -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/cluster_inetport" -v "${IP_ADDRESS}:${CLUSTER_INET_PORT}" ${ARCHAPPL_APPLIANCES}

        if [ "${USE_SSL}" = true ]; then
            setup_ssl_certs
        else
            # Force HTTP
            xmlstarlet ed -L -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" -v "http://${IP_ADDRESS}:${APPLIANCE_PORT}/${APPLIANCE_UNIT}/bpl" ${ARCHAPPL_APPLIANCES}

            # Appends new connector
            xmlstarlet ed -L -u "/Server/Service/Connector[@protocol='HTTP/1.1']/@port" -v ${APPLIANCE_PORT} ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

            # Remove every other connector entry from the conf/server.xml
            xmlstarlet ed -L -d "/Server/Service/Connector[@protocol!='HTTP/1.1']" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
        fi

        if [ "${USE_AUTHENTICATION}" = true ]; then
            setup_ldap_realm
        fi

    fi

    RAND_SRV_PORT=$((RAND_SRV_PORT + 1))
done

build_appliances

update_appliance_config
