#!/bin/sh

#
# A script to download and compile EPICS base.
#
# Gustavo Ciotto Pinton
# Controls Group - Brazilian Synchrotron Light Source Laboratory - LNLS
#

# Setting EPICS base up

wget -P ${EPICS_INSTALL_DIR} ${EPICS_BASE_URL}

mkdir -p ${EPICS_INSTALL_DIR}/${EPICS_BASE_NAME}

tar -xvzf ${EPICS_INSTALL_DIR}/${EPICS_BASE_TAR_NAME}.tar.gz -C ${EPICS_INSTALL_DIR}/

rm ${EPICS_INSTALL_DIR}/${EPICS_BASE_TAR_NAME}.tar.gz

grep -r "IPPORT_USERRESERVED" ${EPICS_INSTALL_DIR}/${EPICS_BASE_NAME}/

make -C ${EPICS_INSTALL_DIR}/${EPICS_BASE_NAME}/



