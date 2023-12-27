# The Mattermost manager

## Introduction
Running a Mattermost server for years requires management on your self-hosted Mattermost server. 
The longer you run it you wil need to do upgrades and cleanups once storage is getting out of hand.
In the 'free' version of Mattermost it is not possible to manage disk use.

The Matttermost website does have pretty good instructions on how to upgrade, but there are quite some manuall steps to make this work. This script will address all those manual steps and gives you the option to update to the 'Extended Support Releases' or to update to the lateste version.

## Scripts

### mattermost_upgrader.sh
This script is there to update your mattermost install and gives you options to either go for the ESR version which is more stable, or just go with the latest and greatest.

Features of the tool are:
* Automatic lookups for the latest versions
* Backup of mattermost folder before upgrade
* Preservation of custom plugins.

### create_mattermost.sh
Mainly created for quick fresh installs to test upgrading. But also handy if you want to install Mattermost yourself. This script is work in progress.


## Plans for the future

* Create an installer for a new mattermost instance.
* Create cleaning and management tooling.





