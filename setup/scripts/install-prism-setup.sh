#!/bin/bash

# installing the setup scripts that helps users to configure prism environment

VERSION='1.0.0'

# load config
source ./settings.sh

# copy settings
cp ./settings.sh ${PRISM_BIN_PATH}/bin/setup/

# copy init script
cp ../bin/setup/roslin-init.sh ${PRISM_BIN_PATH}/bin/setup/roslin-init.sh

# copy remove-settings script
cp ../bin/setup/roslin-deinit.sh ${PRISM_BIN_PATH}/bin/setup/roslin-deinit.sh

# copy and configure jumpstart example
tar cvzf ${PRISM_BIN_PATH}/bin/setup/examples.tgz ../data/examples/*

if [ "$PRISM_SYSTEM_WIDE_INSTALL" == "YES" ]
then
    echo "PATH=\$PATH:${PRISM_BIN_PATH}/bin/setup" | sudo tee /etc/profile.d/prism-setup.sh
fi
