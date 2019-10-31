#!/bin/bash
# set -x

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SCRIPT_GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$SCRIPT_GIT_BRANCH" != "HEAD" ]; then
    SCRIPT_GIT_REMOTE="$(git config --local --get branch.$SCRIPT_GIT_BRANCH.remote)"
    SCRIPT_GIT_REPO_BASE="$(git config --local --get remote.$SCRIPT_GIT_REMOTE.url | sed -E 's/\/[A-Za-z0-9-]+\.git//g')"
else
    SCRIPT_GIT_REPO_BASE="https://github.com/SolaceLabs"
fi


export WIN_DRIVE=${WIN_DRIVE:-"/mnt/c"}
export VIRTUALBOX_HOME=${VIRTUALBOX_HOME:-"$WIN_DRIVE/Program Files/Oracle/VirtualBox"}
export GIT_REPO_BASE=${GIT_REPO_BASE:-"$SCRIPT_GIT_REPO_BASE"}
export WORKSPACE=${WORKSPACE:-$HOME/workspace}
export SETTINGS_FILE=${SETTINGS_FILE:-$HOME/.settings.sh}
export REPOS_DIR=${REPOS_DIR:-$HOME/repos}

SETUP_LOG_FILE=${SETUP_LOG_FILE:-"$WORKSPACE/$SCRIPT.log"}

# vboxmanage has to be able to see $HOME/.bosh_virtualbox_cpi in the Windows filesystem.
# Therefore we create the files there, and link to them from the Linux home.
function setupLinks() {
    if [ ! -e $HOME/.bosh_virtualbox_cpi ]; then
        mkdir -p $WIN_DRIVE$HOME/.bosh_virtualbox_cpi
        ln -s $WIN_DRIVE$HOME/.bosh_virtualbox_cpi $HOME/.bosh_virtualbox_cpi
    fi

    if [ ! -e /usr/local/bin/VBoxManage ]; then
        sudo ln -s "$VIRTUALBOX_HOME/VBoxManage.exe" /usr/local/bin/VBoxManage
        sudo ln -s "$VIRTUALBOX_HOME/VBoxManage.exe" /usr/local/bin/vboxmanage
    fi
}

function cloneRepo() {
    if [ ! -d $REPOS_DIR ]; then
        mkdir $REPOS_DIR
    fi
    (
        cd $REPOS_DIR
        if [ ! -d pubsubplus-cf-dev ]; then
        (
            git clone $GIT_REPO_BASE/pubsubplus-cf-dev.git
            cd pubsubplus-cf-dev
            if [ ! -z $BRANCH ]; then
                git checkout $BRANCH
            fi
        )
        fi

        if [ ! -f pubsubplus-cf-dev/cf-pubsubplus-deployment/README.md ]; then
        (
            cd pubsubplus-cf-dev
            git clone $GIT_REPO_BASE/cf-pubsubplus-deployment.git
            cd cf-pubsubplus-deployment
            if [ ! -z $BRANCH ]; then
                git checkout $BRANCH
            fi
        )
        fi
    )
}

function installBosh() {
    $REPOS_DIR/pubsubplus-cf-dev/bin/bosh_lite_vm.sh -c
    if [ ! -e /usr/local/bin/bosh ]; then
        sudo cp $REPOS_DIR/pubsubplus-cf-dev/bucc/bin/bosh /usr/local/bin
    fi
}

function deployCf() {
    source $WORKSPACE/bosh_env.sh
    $REPOS_DIR/pubsubplus-cf-dev/bin/cf_deploy.sh
}

function installPrograms() {

    if [ ! -e /usr/local/bin/cf ]; then
        # Install the cf cli tool.
        curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github" | tar -zx
        sudo mv cf /usr/local/bin

        sudo apt-get update

        sudo apt-get install -y jq build-essential zlibc zlib1g-dev ruby ruby-dev rubygems openssl libssl-dev libxslt-dev libxml2-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3
        sudo gem install bundler
    fi
}

function getSettingsEnv() {
    echo "export PUBSUBPLUS_CF_DEV=$REPOS_DIR/pubsubplus-cf-dev"
    echo "export WORKSPACE=$WORKSPACE"
    echo "export PATH=\$PATH:\$PUBSUBPLUS_CF_DEV/bucc/bin"
}

function createSettingsFile() {

	if [ ! -f $SETTINGS_FILE ]; then
		echo "Capturing settings in $SETTINGS_FILE"
	        getSettingsEnv >> $SETTINGS_FILE
	fi
}

function alterProfile() {
    NUM_LINES=$( grep -c "source $SETTINGS_FILE" ~/.profile )

    if [ "$NUM_LINES" -eq 0 ]; then
        read -p "Would you like  your .profile modified to automatically set up the CF environment when you next log in? (yN): "

        if [[ $REPLY =~ ^[Yy] ]]; then
            echo "source $SETTINGS_FILE" >> ~/.profile
            echo "source $REPOS_DIR/pubsubplus-cf-dev/.profile" >> ~/.profile
        fi
    fi
}

pre_install=0
bosh_lite=0
cloudfoundry=0

function setupLinuxOnWsl() {

    cd
    set -e
    if [ $pre_install == 1 ]; then
        setupLinks
        installPrograms
        cloneRepo
    fi
    if [ $bosh_lite == 1 ]; then
        installBosh
    fi
    if [ $cloudfoundry == 1 ]; then
        deployCf
        createSettingsFile
        alterProfile
    fi
    set +e
}

function show_help() {
    echo "-p Runs pre install commands that are necessary for BOSH and CF"
    echo "-b Installs BOSH"
    echo "-c Installs CF ontop of BOSH"
}

function parseCommandLineArguments() {
    
    if [ $# -eq 0 ]; then
        pre_install=1
        bosh_lite=1
        cloudfoundry=1
        return 0
    fi
    
    # A POSIX variable
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    while getopts "h?pbc" opt; do
	case "$opt" in
	h|\?)
	    show_help
	    exit 0
	    ;;
	p)  pre_install=1
	    ;;
        b)  bosh_lite=1
            ;;
        c)  cloudfoundry=1
            ;;
	esac
    done

    shift $((OPTIND-1))

    [ "${1:-}" = "--" ] && shift

}


#### 
parseCommandLineArguments $@
setupLinuxOnWsl | tee $SETUP_LOG_FILE

echo "Setup log file: $SETUP_LOG_FILE"
