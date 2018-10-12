#!/bin/bash

IKIO_VERSION=0.1
IKIO_OS=`cat /etc/os-release | grep ^ID= | cut -d "=" -f 2`
IKIO_OS="${IKIO_OS%\"}"
IKIO_OS="${IKIO_OS#\"}"

IKIO_OS_VERSION=`cat /etc/os-release | grep VERSION_ID= | cut -d "=" -f 2 | cut -d "\"" -f 2`
IKIO_OS_VERSION_CODENAME=`cat /etc/os-release | grep VERSION_CODENAME= | cut -d "=" -f 2 | cut -d "\"" -f 2`


P_ODOO_VERSION=11
P_PG_VERSION=10
P_USERNAME=$USER
P_PASSWORD=$USER
P_LOCALE="fr_FR.UTF-8"
P_LOCALE_LANG=(${P_LOCALE//./ })
P_DEBUG=
SCRIPT_COMMAND=


#
# Test shell and exec environment compliance
#
function test_script_prerequisites {
    getopt --test > /dev/null
    if [[ $? -ne 4 ]]; then
        echo "Required getopt is not available. Execution aborted."
        exit 1
    fi
    whotest[0]="test" || (echo 'Required Arrays are not supported in this version of bash. Execution aborted.' && exit 2)
}


function print_prolog {
    echo 
    echo "obinstall.sh version $IKIO_VERSION"
    echo "(c) 2018 Cyril MORISSE / @cmorisse"
    echo 
}


function print_intro_message {
    echo " use obinstall.sh help for usage instructions."
    echo 
}

function print_help_message {
    echo "Usage: ./obinstall.sh {options} command"
    echo
    echo "Available options:"
#    echo "  -O/--odoo-version   Odoo version to install: 8, 9, 10, 11 or 12 (default=$P_ODOO_VERSION)"
    echo "  -P/--pg-version     PostgreSQL version to install: 9.6, 10 or 11 (default=$P_PG_VERSION)"
    echo "  -U/--username       PostgreSQL username used in buildout.cfg (default=$P_USERNAME)"
    echo "  -W/--password       PostgreSQL password used in buildout.cfg (default=$P_PASSWORD)"
    echo "  -L/--locale         PostgreSQL Locale used (default=$P_LOCALE)"
    echo "  -D/--debug          Displays debugging information"
    echo    
    echo "Available commands:"
    echo "   help               Prints this message."
    echo "   setup-locale       Setup locale (default=$P_LOCALE)"
    echo "   prerequisites      Installs system prerequisites specific to \"$IKIO_OS $IKIO_OS_VERSION\""
    echo "   postgresql         Installs postgreSQL."
    echo "   odoo               Installs Odoo."
    echo "   dependencies       Installs dependencies specific to this project."
    echo "   reset              Remove all buildout installed files."
    echo 
    exit
}

function parseargs {
    #
    # Defined support options and use getopts to parse parameters
    #
    OPTIONS=O:U:W:L:D
    LONG_OPTIONS=odoo-version:,pg-version:,username:,password:,locale:,debug
    
    PARSED=$(getopt --options=$OPTIONS --longoptions=$LONG_OPTIONS --name "$0" -- "$@")
    if [[ $? -ne 0 ]]; then
        # e.g. $? == 1
        #  then getopt has complained about wrong arguments to stdout
        exit 2
    fi
    
    # 
    # process getopts recognized options until we see -- 
    #
    eval set -- "$PARSED"
    while true; do
        case "$1" in
            -O|--odoo-version)
                P_ODOO_VERSION="$2"
                shift 2
                ;;
            -P|--pg-version)
                P_PG_VERSION="$2"
                shift 2
                ;;
            -U|--username)
                P_USERNAME="$2"
                P_PASSWORD="$2"
                shift 2
                ;;
            -W|--password)
                P_PASSWORD="$2"
                shift 2
                ;;
            -L|--locale)
                P_LOCALE="$2"
                P_LOCALE_LANG=(${P_LOCALE//./ })                
                shift 2
                ;;
            -D|--debug)
                P_DEBUG=true
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Script Internal Error"
                exit 3
                ;;
        esac
    done
    
    #
    # now process commands
    #
    for i in "$@" ; do
        case $i in
            #
            # Commands
            #
            help)  # Install odoo command
            SCRIPT_COMMAND=print_help_message
            shift # past argument with no value
            ;;
            odoo)  # Install odoo command
            SCRIPT_COMMAND=install_odoo
            shift # past argument with no value
            ;;
            reset)  # Reset odoo install
            SCRIPT_COMMAND=reset_odoo
            shift # past argument with no value
            ;;
            setup-locale)  # Setup Linux locale
            SCRIPT_COMMAND=setup_locale
            shift # past argument with no value
            ;;
            prerequisites)  # Install odoo command
            SCRIPT_COMMAND=install_prerequisites
            shift # past argument with no value
            ;;
            postgresql)  # Install odoo command
            SCRIPT_COMMAND=install_postgresql
            shift # past argument with no value
            ;;
            dependencies)  # Install odoo command
            SCRIPT_COMMAND=install_dependencies
            shift # past argument with no value
            ;;
            devtest)  # This is an undocumented command used for script writing and debugging
            SCRIPT_COMMAND=dev_test
            shift # past argument with no value
            ;;
            *)
                echo "Unrecognized command: \"$1\" aborting."
                exit 3
            ;;
        esac
    done
    
    if [ -z $SCRIPT_COMMAND ]; then # string length is 0
    #then 
        SCRIPT_COMMAND=print_intro_message
    fi

    if [ $P_DEBUG ]; then
        echo "debug: PARSED=${PARSED}"
        echo "debug: P_ODOO_VERSION           = ${P_ODOO_VERSION}"
        echo "debug: P_LOCALE                 = ${P_LOCALE}"
        echo "debug: P_LOCALE_LANG            = ${P_LOCALE_LANG}"
        echo "debug: P_USERNAME               = ${P_USERNAME}"
        echo "debug: P_PASSWORD               = ${P_PASSWORD}"
        echo "debug: P_DEBUG                  = ${P_DEBUG}"
        echo "debug: SCRIPT_COMMAND           = ${SCRIPT_COMMAND}"
        echo "debug: IKIO_OS                  = ${IKIO_OS}"
        echo "debug: IKIO_OS_VERSION          = ${IKIO_OS_VERSION}"
        echo "debug: IKIO_OS_VERSION_CODENAME = ${IKIO_OS_VERSION}"
    fi
}

# https://superuser.com/questions/789448/choosing-between-bashrc-profile-bash-profile-etc
function reload_shell {
    if [ -f ~/.profile ]; then
        echo "Reloading ~/.profile"
        source ~/.profile
    else 
        echo "Reloading ~/.bash_profile"
        source ~/.bash_profile
    fi
}


# We need to add P_LOCALE as we will use it to install postgresql

function setup_locale {

    # Add the locale
    if [ $IKIO_OS$IKIO_OS_VERSION == ubuntu18.04 ]; then
        sudo apt install -y language-pack-fr
        sudo update-locale LANGUAGE="fr_FR.UTF-8" LC_ALL="fr_FR.UTF-8"
    else
        sudo locale-gen $P_LOCALE_LANG $P_LOCALE
        sudo update-locale    
    fi
    reload_shell

    # Update bashrc with locale if needed
#    if grep -Fxq "# Added by inouk Odoo install.sh" $HOME/.bashrc ; then
#        echo "Skipping $HOME/.bashrc update"
#    else
#        cat >> /home/ubuntu/.bashrc <<EOT
#
## Added by inouk Odoo install.sh
#export LANG=fr_FR.UTF-8
#export LANGUAGE=fr_FR
#export LC_ALL=fr_FR.UTF-8
#export LC_CTYPE=fr_FR.UTF-8
#EOT
#    fi
    
}

#
# installs all packages on ubuntu 18.04/bionic except from postgresql
function install_packages_ubuntu_bionic {
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y libsasl2-dev python-dev libldap2-dev libssl-dev
 
    sudo apt install -y libz-dev gcc
    sudo apt install -y libxml2-dev libxslt1-dev
    # For Python 3.7
    sudo apt install -y libbz2-dev libreadline-dev libsqlite3-dev
    sudo apt install -y libpq-dev
    sudo apt install -y libldap2-dev libsasl2-dev
    sudo apt install -y libjpeg-dev libfreetype6-dev liblcms2-dev
    sudo apt install -y libopenjp2-7 libopenjp2-7-dev
    sudo apt install -y libwebp5  libwebp-dev
    sudo apt install -y libtiff-dev
    sudo apt install -y libffi-dev
    sudo apt install -y libyaml-dev
    sudo apt install -y bzr mercurial git
    sudo apt install -y curl htop vim tmux
}

#
# installs postgresql ubuntu / debian repository
#
function install_postgresql_repository_ubuntu {
    # we test wether apt.postgresql.org is already in pgdg list
    grep "apt.postgresql.org" /etc/apt/sources.list.d/pgdg.list
    if [ $? -gt 0 ]
    then
        wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -
        echo "Installing Postgresql"
        sudo sh -c "echo \"deb http://apt.postgresql.org/pub/repos/apt/ ${IKIO_OS_VERSION_CODENAME}-pgdg main\" >> /etc/apt/sources.list.d/pgdg.list"
        sudo apt-get update
    fi
}

#
# installs postgresql on ubuntu bionic
# For bionic default postgresql version is 10
#
function install_postgresql_ubuntu {
    
    if [ $P_PG_VERSION == 9.6 ]; then
        echo "Installing postgreSQL 9 from Official postgresql.org repository."
        sudo apt-get install postgresql-9.6 postgresql-contrib-9.6
    elif [ $P_PG_VERSION == 10 ]; then
        echo "Installing postgreSQL 10 from Official postgresql.org repository."
        sudo apt-get install postgresql-10 postgresql-contrib-10
    elif [ $P_PG_VERSION == 11 ]; then
        echo "Installing postgreSQL 11 from Official postgresql.org repository."
        sudo apt-get install postgresql-11 postgresql-contrib-11
    else
        echo "Unsupported postgresql: \"$P_PG_VERSION\" version. See help." 
        exit 1
    fi
}


function install_postgresql {
    if [ $IKIO_OS == ubuntu ]; then
        install_postgresql_repository_ubuntu
        install_postgresql_ubuntu
        sudo su - postgres -c "psql -c \"CREATE ROLE $P_USERNAME WITH LOGIN SUPERUSER CREATEDB CREATEROLE PASSWORD '$P_PASSWORD';\""
        sudo su - postgres -c "psql -c \"CREATE DATABASE $P_USERNAME;\""
    fi
}


function install_pyenv {

    if [ ! -f ~/.obinstallsh.pyenv ]; then
        git clone https://github.com/pyenv/pyenv.git ~/.pyenv
        grep "# obinstall.sh added pyenv" ~/.bashrc
        if [ $? -gt 0 ]
        then
            cat >> /home/ubuntu/.bashrc << 'EOT'

#
# obinstall.sh added pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init -)"
fi

EOT
            touch ~/.obinstallsh.pyenv

            # reload shell
            export PYENV_ROOT="$HOME/.pyenv"
            export PATH="$PYENV_ROOT/bin:$PATH"
            if command -v pyenv 1>/dev/null 2>&1; then
                eval "$(pyenv init -)"
            fi
        fi
    else
        echo "Skipping pyenv install. Delete ~/.obinstallsh.pyenv to force installation."
    fi    
}

function install_py37 {
    if [ ! -f ~/.obinstallsh.py37 ]; then
        echo "Installing Python 3.7"
        pyenv install 3.7.0
        pyenv local 3.7.0
        touch ~/.obinstallsh.py37
        echo "Python 3.7.0 installed."
    else
        echo "Skipping Python 3.7.0 install. Delete ~/.obinstallsh.py37 to force installation."
    fi    
}

function generate_buildoutcfg {
    # create a basic buildout.cfg if none is found
    if [ ! -f buildout.cfg ]; then    
        cat >> buildout.cfg <<EOT 
[buildout]
extends = appserver.cfg

[openerp]
options.admin_passwd = admin
options.db_user = $P_USERNAME
options.db_password = $P_PASSWORD
options.db_host = 127.0.0.1
options.db_port = False
#options.db_name = test01_v11
#options.dbfilter = ^cmo_.*_v11$
#options.http_port = 8080
EOT
    fi    

}

function install_wkhtml2pdf_amzn {
    # wkhtmltopdf
    echo "Installing wkhtml2pdf on Amazon Linux"
    wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox-0.12.5-1.centos7.x86_64.rpm
    sudo yum install -y wkhtmltox-0.12.5-1.centos7.x86_64.rpm
    rm wkhtmltox-0.12.5-1.centos7.x86_64.rpm
}

function install_wkhtml2pdf_ubuntu {
    # wkhtmltopdf
    if [ $IKIO_OS_VERSION_CODENAME == bionic ]; then
        echo "Installing wkhtml2pdf on Ubuntu Bionic"
        sudo apt install -y fontconfig fontconfig-config fonts-dejavu-core libfontconfig1 libfontenc1 libxrender1 x11-common xfonts-75dpi xfonts-base xfonts-encodings xfonts-utils
        wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb
        sudo sudo dpkg -i wkhtmltox_0.12.5-1.bionic_amd64.deb
        rm wkhtmltox_0.12.5-1.bionic_amd64.deb
    else
        echo "wkhtml2pdf installatiob obn Ubuntu $IKIO_OS_VERSION_CODENAME not implemented"
        exit 1
    fi
}

# installs all system prerequistes
function install_prerequisites {
    install_packages_${IKIO_OS}_${IKIO_OS_VERSION_CODENAME}
    install_wkhtml2pdf_${IKIO_OS}
    install_pyenv
    install_py37
    echo "Prerequisites installation finished. You must reconnect to update shell environment."
}


function install_odoo {
    
    generate_buildoutcfg

    if [ -d py37 ]; then
        echo "install.sh has already been launched."
        echo "So you must either use bin/buildout to update or launch \"install.sh reset\" to remove all buildout installed items."
        exit -1
    fi
    python3 -m venv py37
    py37/bin/pip install --upgrade pip
    py37/bin/pip install --upgrade setuptools==39.0.1
    py37/bin/pip install zc.buildout==2.12.2
    py37/bin/pip install $PYPI_INDEX cython==0.28.5
    py37/bin/buildout

    
    #if [ $RUNNING_ON == "Darwin" ]; then
    #    echo "Running on Darwin."
    #    py27/bin/pip install python-ldap==2.4.28 --global-option=build_ext --global-option="-I$(xcrun --show-sdk-path)/usr/include/sasl"
    #fi    
    # We install pyusb here it fails with buildout
    #py36/bin/pip install $PYPI_INDEX pyusb==1.0.0
    #py36/bin/pip install $PYPI_INDEX num2words==0.5.4
    echo
    echo "Your commands are now available in ./bin"
    echo "Python is in ./py36. Don't forget to launch 'source py36/bin/activate'."
    echo 
}

function reset_odoo {
    echo "Removing all buildout generated items..."
    echo "    Not removing downloads/ and eggs/ for performance reason."
    rm -rf .installed.cfg
    rm -rf bin/
    rm -rf develop-eggs/
    rm -rf develop-src/
    rm -rf etc/
    rm -rf py3?/
    rm -rf py2?/
    rm -rf bootstrap.py
    rm -rf eggs/
    echo "    Done."
}


function dev_test {
    install_wkhtml2pdf_${IKIO_OS}
}


test_script_prerequisites
print_prolog
# call parseargs passing it all parameters received from 
parseargs $@
$SCRIPT_COMMAND


