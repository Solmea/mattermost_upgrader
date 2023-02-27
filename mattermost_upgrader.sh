#!/bin/bash
#
# Mattermost upgrade script on local installed instances
#
# Written by Roalt Zijlstra - 20220822
MMU_VERSION=7.0

UPGRADE_FILE=""
UPGRADE_EDITION="enterprise"
UPGRADE_ESR_ONLY="false"
DEBUG=false

# We expect the running mattermost directory in the following place.
ALTERNATIVE_ROOT=/home/mattermost
if [  -d /var/mattermost ]; then
	MATTERMOST_ROOT=/var
else
	if [  -d /opt/mattermost ]; then
 		MATTERMOST_ROOT=/var
	else
		echo "No default location found for mattermost. Trying the alternative location." 
		
		if [  -d /opt/mattermost ]; then
 			MATTERMOST_ROOT=/var
		else
			echo "No mattermost folder found in ${ALTERNATIVE_ROOT} or /opt or /var" 
			exit
		fi
	fi
fi

# Check for a running process

cd /var/tmp

function usage() {
echo "$0 usage: "
echo " -f <upgrade file>    - upgrade with specified file"
echo " -s                   - Upgrade to ESR version only"
echo " -e <team|enterprise> - Specify the kind of edition version which you want to upgrade to.  "
exit 0;
}

echo "Mattermost server updater ${MMU_VERSION} "

# parse arguments
while getopts ":he:f:s" arg; do
  case $arg in
    e) # Specify p value.
        if [ "${OPTARG}" = "team" ] ||
           [ "${OPTARG}" = "enterprise" ]; then
           UPGRADE_EDITION="${OPTARG}"
           if [ "${UPGRADE_EDITION}" = "team" ]; then
              UPGRADE_EDITION="mattermost-team"
           fi
        fi
      ;;
    f) # Specify an upgrade file
      UPGRADE_FILE=${OPTARG}
      ;;
    s) # ESR only mode
      UPGRADE_ESR_ONLY="true"
      ;;
    h | *) # Display help.
      usage
      exit 0
      ;;
  esac
done

if [ ${DEBUG} = true ]; then
        echo ${UPGRADE_EDITION}
        echo "Optional file upgrade ${UPGRADE_FILE}"
        if [ "${UPGRADE_ESR_ONLY}" = "true" ]; then
                echo "ESR only edition"
        fi
fi

function upgrade_mattermost() {
        MY_ROOT=$1
        MY_FILE=$2
        echo "Root is ${MY_ROOT}"
        echo "File is ${MY_FILE}"

        if [ ! -d ${MY_ROOT}/mattermost ]; then
                echo "No mattermost install dir found. "
                return
        fi
        cd ${MY_ROOT}
        # The transform option adds a suffix to the topmost extracted directory so it does not conflict with the usual install directory.
        tar -xf ${MY_FILE} --transform='s,^[^/]\+,\0-upgrade,'

        # stop the service
        echo "Stopping mattermost"
        service mattermost stop

        # backup mattermost
        echo "Making a backup in mattermost-back-$(date +'%F-%H-%M')"
        cp -ra mattermost/ mattermost-back-$(date +'%F-%H-%M')/

        # Removing non-custom files.
        find mattermost/ mattermost/client/ -mindepth 1 -maxdepth 1 \! \( -type d \( -path mattermost/client -o -path mattermost/client/plugins -o -path mattermost/config -o -path mattermost/logs -o -path mattermost/plugins -o -path mattermost/data \) -prune \) | sort | xargs rm -r

        # Rename the plugins directories so they do not interfere with the upgrade.
        mv mattermost/plugins/ mattermost/plugins~
        mv mattermost/client/plugins/ mattermost/client/plugins~

        # Change ownership of the new files before copying them.
        chown -hR mattermost:mattermost mattermost*upgrade/

        cp -avn mattermost*upgrade/. mattermost/
        rm -r mattermost*upgrade/

        # Start the service
        echo "Starting mattermost"
        service mattermost start

        echo "Upgrade your config.json schema:"
        echo
        echo "Open the System Console and change a setting, then revert it. This should enable the Save button for that page."
        echo "Click Save."
        echo "Refresh the page."
        echo "Your current settings are preserved, and new settings are added with default values."

        read -p "Is the upgrade your config.json done? (yes/no) " BLAH
        if [ "$BLAH" = "yes" ]; then
                echo "Now we sync back your plugin settings."
                cd ${MY_ROOT}/mattermost
                rsync -au plugins~/ plugins
                rm -rf plugins~
                rsync -au client/plugins~/ client/plugins
                rm -rf client/plugins~
                chown -Rf mattermost:mattermost client/plugins
                chown -Rf mattermost:mattermost plugins

                service mattermost restart
        fi
}

if [ "${UPGRADE_FILE}" = "" ]; then
        # Try to get the latest version number from the Version Archive
        wget -o /var/tmp/version-archive.log -O /var/tmp/version-archive.html  https://docs.mattermost.com/upgrade/version-archive.html
        grep releases.mattermost.com  /var/tmp/version-archive.html  | grep -i "${UPGRADE_EDITION}" | grep ESR |  head -1 | sed 's/href="/\n/g' | sed 's/">Download/\n/g' > /var/tmp/frops-esr
        grep releases.mattermost.com  /var/tmp/version-archive.html  | grep -i "${UPGRADE_EDITION}" | head -1 | sed 's/href="/\n/g' | sed 's/">Download/\n/g' > /var/tmp/frops
        URL_ESR=$(grep "releases.mattermost.com" /var/tmp/frops-esr)
        UPGRADE_ESR_VERSION=$( echo $URL_ESR | cut -d '/' -f 4 )
        UPGRADE_ESR_FILE=/var/tmp/$( echo $URL_ESR | cut -d '/' -f 5 )
        URL=$(grep "releases.mattermost.com" /var/tmp/frops)
        UPGRADE_VERSION=$( echo $URL | cut -d '/' -f 4 )
        UPGRADE_FILE=/var/tmp/$( echo $URL | cut -d '/' -f 5 )
        if [ "${UPGRADE_ESR_ONLY}" = "true" ]; then
                UPGRADE_VERSION=${UPGRADE_ESR_VERSION}
                UPGRADE_FILE=${UPGRADE_ESR_FILE}
                URL=${URL_ESR}
        fi
        if [ ! -f ${UPGRADE_FILE} ]; then
                wget ${URL}
        else
                echo "Upgrade file is already downloaded. (${UPGRADE_FILE})"
        fi
else
        echo "File: $UPGRADE_FILE"
        UPGRADE_VERSION=$(echo $UPGRADE_FILE | cut -d '-' -f 2 )

fi

MATTERMOST_VERSION=$(${MATTERMOST_ROOT}/mattermost/bin/mattermost version | grep "Build Number" | cut -d ':' -f 2 | sed 's/ //g')
if [ "${UPGRADE_ESR_ONLY}" = "false" ]; then
        echo "The latest version of Mattermost is: ${UPGRADE_VERSION}"
fi
if [ "${UPGRADE_ESR_VERSION}" != "${UPGRADE_VERSION}" ]; then
        echo "If you wish to install the ESR version, please specify the '-s' switch or give the upgrade tar file"
fi
echo "The latest Extended Support Edition is: ${UPGRADE_ESR_VERSION}"
echo "Installed version : ${MATTERMOST_VERSION}"

if [ "${MATTERMOST_VERSION}" != "${UPGRADE_VERSION}" ]; then
        echo "To be used upgrade file is: ${UPGRADE_FILE} "
        read -p "Do you want to upgrade to version ${UPGRADE_VERSION} ? (yes/no) " ANSWER
        if [ "${ANSWER}" = "yes" ]; then
                # Do the upgrade
                echo "Start upgrade to ${UPGRADE_VERSION}"
                upgrade_mattermost ${MATTERMOST_ROOT} ${UPGRADE_FILE}
        else
                echo "Fine we do nothing now."
        fi
fi
