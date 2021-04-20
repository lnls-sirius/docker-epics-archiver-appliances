#!/bin/bash
set -a
set -e
set -x

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
        -alias ${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}\
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
        -alias ${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}\
        -storepass ${CERTIFICATE_PASSWORD}\
        -file ${APPLIANCE_CERTS_FOLDER}/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.crt
    fi

    # Imports certificate into trusted keystore
    for IDENTITY in $(xmlstarlet sel -t -v "/appliances/appliance/identity" ${ARCHAPPL_APPLIANCES}); do
        # In case of multiple appliances, loop until we have all required crts
        CRT_FILE=${APPLIANCE_CERTS_FOLDER}/${IDENTITY}-${APPLIANCE_UNIT}.crt
        while [ ! -f ${CRT_FILE} ]; do
            echo "CRT ${CRT_FILE} does not exists"
            sleep 2
        done

        keytool \
            -import\
            -alias ${IDENTITY}-${APPLIANCE_UNIT}\
            -trustcacerts\
            -storepass ${CERTIFICATE_PASSWORD}\
            -noprompt\
            -keystore /usr/local/openjdk-15/lib/security/cacerts \
            -file ${CRT_FILE}
    done

    # Copies keystore to conf/
    cp --verbose ${APPLIANCE_CERTS_FOLDER}/${ARCHAPPL_MYIDENTITY}-${APPLIANCE_UNIT}.keystore ${CATALINA_HOME}/conf/

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

    xmlstarlet ed -L \
        -s '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']' \
        -t elem -n "SSLHostConfig" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

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
        xmlstarlet ed -L\
            -i '/Server/Service/Engine/Host/Realm' \
            -t attr -n "roleName" -v "${CONNECTION_ROLE_NAME}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
    fi

    if [ ! -z ${CONNECTION_ROLE_SEARCH+x} ]; then
        xmlstarlet ed -L\
            -i '/Server/Service/Engine/Host/Realm'\
            -t attr -n "roleSearch" -v "${CONNECTION_ROLE_SEARCH}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
    fi

    if [ ! -z ${CONNECTION_NAME+x} ]; then
        xmlstarlet ed -L\
            -i '/Server/Service/Engine/Host/Realm' \
            -t attr -n "connectionName" -v "${CONNECTION_NAME}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
    fi

    if [ ! -z ${CONNECTION_PASSWORD+x} ]; then
        xmlstarlet ed -L\
            -i '/Server/Service/Engine/Host/Realm'\
            -t attr -n "connectionPassword" -v "${CONNECTION_PASSWORD}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
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

function create_appliance_dir_structure {
    set +x
    echo "Creating ${APPLIANCE_UNIT} dir structure"
    echo ""
    set -x

    mkdir --verbose --parents ${CATALINA_HOME}/${APPLIANCE_UNIT}
    cp --verbose --recursive ${CATALINA_HOME}/conf ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf
    cp --verbose --recursive ${CATALINA_HOME}/webapps ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps

    mkdir --verbose --parents ${CATALINA_HOME}/${APPLIANCE_UNIT}/logs
    mkdir --verbose --parents ${CATALINA_HOME}/${APPLIANCE_UNIT}/temp
    mkdir --verbose --parents ${CATALINA_HOME}/${APPLIANCE_UNIT}/work
}

function update_appliance_log_settings {
    set +x
    echo "Update ${APPLIANCE_UNIT} log settings"
    set -x

    # Overwrite log4j settings if possible
    if [ -f "${APPLIANCE_FOLDER}/configuration/${APPLIANCE_UNIT}-log4j.properties" ]; then
        cp \
            --verbose\
            --force\
            "${APPLIANCE_FOLDER}/configuration/${APPLIANCE_UNIT}-log4j.properties"\
            ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}/WEB-INF/classes/log4j.properties
    fi
}

function update_appliance_url {
    # Force https in case of USE_SSL and MGMT unit
    [[ "${APPLIANCE_UNIT}" = "mgmt" ]] && [[ "${USE_SSL}" = true ]] && \
        UNIT_URL="https://${IP_ADDRESS}:${APPLIANCE_PORT}/${APPLIANCE_UNIT}" ||\
        UNIT_URL="http://${IP_ADDRESS}:${APPLIANCE_PORT}/${APPLIANCE_UNIT}"

    xmlstarlet ed -L\
        -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url"\
        -v "${UNIT_URL}/bpl" ${ARCHAPPL_APPLIANCES}

    if [ "${APPLIANCE_UNIT}" = "retrieval" ]; then
        xmlstarlet ed -L\
            -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/data_retrieval_url"\
            -v "${UNIT_URL}" ${ARCHAPPL_APPLIANCES}
    fi
}

function update_appliance_cluster_inet {
    CLUSTER_INET_PORT=$(xmlstarlet sel -t \
            -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/cluster_inetport"\
            /opt/epics-archiver-appliances/configuration/lnls_appliances.xml | awk -F ':' '{print $2'})
    [[ -z "${CLUSTER_INET_PORT}" ]] && echo "Could not select appliance cluster inet port" && exit -1
    xmlstarlet ed -L\
        -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/cluster_inetport"\
        -v "${IP_ADDRESS}:${CLUSTER_INET_PORT}" ${ARCHAPPL_APPLIANCES}
}

function update_appliance_tomcat {
    # Unit's tomcat server port
    xmlstarlet ed -L -u '/Server/@port' -v ${RAND_SRV_PORT} ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    if [ "${APPLIANCE_UNIT}" = "engine" ] || [ "${APPLIANCE_UNIT}" = "etl" ] || [ "${APPLIANCE_UNIT}" = "retrieval" ]; then
        # Appends new connector
        xmlstarlet ed -L\
            -u "/Server/Service/Connector[@protocol='HTTP/1.1']/@port"\
            -v ${APPLIANCE_PORT} ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

        # Remove every other connector entry from the conf/server.xml
        xmlstarlet ed -L\
            -d "/Server/Service/Connector[@protocol!='HTTP/1.1']" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    elif [ "${APPLIANCE_UNIT}" = "mgmt" ]; then

        if [ "${USE_SSL}" = true ]; then
            setup_ssl_certs
        else
            # Appends new connector
            xmlstarlet ed -L\
                -u "/Server/Service/Connector[@protocol='HTTP/1.1']/@port"\
                -v ${APPLIANCE_PORT} ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

            # Remove every other connector entry from the conf/server.xml
            xmlstarlet ed -L\
                -d "/Server/Service/Connector[@protocol!='HTTP/1.1']" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
        fi

        if [ "${USE_AUTHENTICATION}" = true ]; then
            setup_ldap_realm
        fi
    fi
}

function update_appliance_config {
    set -x
    # Base tomcat server port
    RAND_SRV_PORT=${BASE_TOMCAT_SERVER_PORT:=1600}

    # Sets cluster inet port and host
    update_appliance_cluster_inet

    for APPLIANCE_UNIT in "mgmt" "engine" "retrieval" "etl"; do

        APPLIANCE_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" ${ARCHAPPL_APPLIANCES} | sed "s/.*://" | sed "s/\/.*//")
        echo "${APPLIANCE_UNIT}: Port ${APPLIANCE_PORT}"

        # Early stop if the appliance setting at ${ARCHAPPL_APPLIANCES} is invalid
        [[ -z "${APPLIANCE_PORT}" ]] && echo "Could not select appliance port" && exit -1

        create_appliance_dir_structure

        update_appliance_log_settings

        update_appliance_url

        update_appliance_tomcat

        RAND_SRV_PORT=$((RAND_SRV_PORT + 1))
    done
    set -x
}

# Before starting Tomcat service, change all addresses in lnls_appliances.xml.
IP_ADDRESS=$(hostname)

setup_mysql_connection

update_appliance_config
