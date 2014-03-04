#!/bin/bash
# Microsoft SQL Server ODBC Driver V1.0 for Linux Build unixODBC DriverManager script
# Copyright Microsoft Corp.

# driver name
driver_name="Microsoft SQL Server ODBC Driver V1.0 for Linux"

# required constants
req_os="Linux";
req_proc="x86_64";
req_software=( "wget" "tar" "make" )

# Create a temp directory for intermediate files
tmp=${TMPDIR-/tmp}
tmp=$tmp/"unixODBC".$RANDOM.$RANDOM.$RANDOM
(umask 077 && mkdir $tmp) || {
    echo "Could not create temporary directory for the log file." 2>&1
    exit 1
}

# driver manager constants
dm_name="unixODBC 2.3.2 DriverManager"
dm_dir="unixODBC-2.3.2"
dm_package='unixODBC-2.3.2.tar.gz'
dm_url="ftp://ftp.unixodbc.org/pub/unixODBC/$dm_package"
dm_package_path=$tmp/$dm_package
dm_build_msg=""

libdir='/usr/lib64'
prefixdir='/usr'
sysconfdir='/etc'

log_file=$tmp/build_dm.log

# warning accepted by user or overridden by command line option
warning_accepted=0

function log()
{
    local msg=$*;
    local date=$(date);
    echo "["$date"]" $msg >> $log_file
}

# format a message and status for an 80 character terminal
# this assumes the msg has already been output and this used
# only for printing the status correctly
function echo_status_aligned
{
    local msg=$1
    local status=$2
    # 2 spaces in between the status and the message
    local total_len=$(( ${#msg} + ${#status} + 2 ))

    if [ $total_len -gt 80 ]; then
        echo "Cannot show a message longer than 80 characters"
        exit 1
    fi

    local dots="................................................................................"
    local dot_count=$(( 80 - $total_len ))

    local status_msg=" $(expr substr "$dots" 1 $dot_count) $status"
    echo $status_msg

    return 0
}

# verify that the installation is on a 64 bit OS
function check_for_Linux_x86_64 ()
{
    log "Verifying on a 64 bit Linux compatible OS"

    local proc=$(uname -p);
    if [ $proc != $req_proc ]; then
        log "This installation of the" $dm_name "may only be installed"
        log "on a 64 bit Linux compatible operating system."
        return 1;
    fi

    local os=$(uname -s);
    if [ $os != $req_os ]; then
        log "This installation of the" $dm_name "may only be installed"
        log "on a 64 bit Linux compatible operating system."
        return 1;
    fi

    return 0;
}


function check_wget
{
    log "Checking that wget is installed"

    # if using a file url, wget is not necessary
    if [ "${dm_url##file://}" == "$dm_url" ]; then
        return 0;
    fi

    hash wget &> /dev/null
    if [ $? -eq 1 ]; then
        log "'wget' required to download $dm_name"
        return 1;
    fi

    return 0
}

function check_tar
{
    log "Checking that tar is installed"

    hash tar &> /dev/null
    if [ $? -eq 1 ]; then
        log "'tar' required to unpack $dm_name"
        return 1;
    fi

    return 0
}

function check_make
{
    log "Checking that make is installed"

    hash make &> /dev/null
    if [ $? -eq 1 ]; then
        log "'make' required to build $dm_name"
        return 1;
    fi

    return 0
}


function download
{
    log "Downloading $dm_url"

    # if they use a file:// url then just point the package at that path and return
    # since wget doesn't support file urls
    if [ ${dm_url##file://} != $dm_url ]; then
        dm_package_path=${dm_url##file://}
        dm_dir=`tar tzf $dm_package_path | head -1 | sed -e 's/\/.*//'`
        dm_name="Custom unixODBC $dm_dir"
        log "Using $dm_name"
        make_build_msg
        return 0
    fi

    $(wget -a $log_file -P $tmp $dm_url  )

    if [ ! -e $dm_package_path ]; then
        log "Failed to retrieve $dm_name from $dm_url."
        return 1;
    fi

    return 0
}

function unpack
{
    log "Unpacking $dm_package_path to $tmp"

    $(tar --directory=$tmp -xvzf $dm_package_path >> $log_file 2>&1)

    if [ $? -ne 0 ]; then
        log "Unpacking $dm_package_path failed."
        return 1
    fi

    return 0
}

function configure_dm
{
    log "Configuring"

    # we set this here rather than at the top to delay the eval of
    # the variables in the string
    local config_options=(
                "--enable-gui=no"
                "--enable-drivers=no"
                "--enable-iconv"
                "--with-iconv-char-enc=UTF8"
                "--with-iconv-ucode-enc=UTF16LE"
                "--libdir=$libdir"
                "--prefix=$prefixdir"
                "--sysconfdir=$sysconfdir"
               )

    $(cd $tmp/$dm_dir >> $log_file 2>&1; ./configure ${config_options[@]} >> $log_file 2>&1)

    if [ $? -ne 0 ]; then
        log "Failed to configure $dm_name"
        return 1
    fi

    return 0
}

function make_dm
{
    log "Building"

    $(cd $tmp/$dm_dir >> $log_file 2>&1 ; make >> $log_file 2>&1)

    if [ $? -ne 0 ]; then
        log "Failed to make $dm_name"
        return 1
    fi

    return 0
}

function make_build_msg
{
    dm_build_msg=(
        "Verifying processor and operating system"
        "Verifying wget is installed"
        "Verifying tar is installed"
        "Verifying make is installed"
        "Downloading $dm_name"
        "Unpacking $dm_name"
        "Configuring $dm_name"
        "Building $dm_name"
    )
}

function build
{
    local build_steps=( check_for_Linux_x86_64 check_wget check_tar check_make  download unpack configure_dm make_dm )
        make_build_msg
    local build_neutral=( "NOT ATTEMPTED" "NOT ATTEMPTED" "NOT ATTEMPTED" "NOT ATTEMPTED" "NOT ATTEMPTED" "NOT ATTEMPTED"
        "NOT ATTEMPTED" "NOT ATTEMPTED" )
    local build_success=( 'OK' 'OK' 'OK' 'OK' 'OK' 'OK' 'OK' 'OK' )
    local build_fail=( 'FAILED' 'FAILED' 'FAILED' 'FAILED' 'FAILED' 'FAILED' 'FAILED' 'FAILED' )

    # asserts for the arrays above
    if [ ${#build_steps[@]} -ne ${#dm_build_msg[@]} ]; then
        echo "Build steps and build message array out of sync"
        exit 1
    fi

    if [ ${#build_steps[@]} -ne ${#build_neutral[@]} ]; then
        echo "Build steps and build message array out of sync"
        exit 1
    fi

    if [ ${#build_steps[@]} -ne ${#build_success[@]} ]; then
        echo "Build steps and build message array out of sync"
        exit 1
    fi

    if [ ${#build_steps[@]} -ne ${#build_fail[@]} ]; then
        echo "Build steps and build message array out of sync"
        exit 1
    fi

    local status=0

    for (( i = 0; i < ${#build_steps[@]}; i++ ))
    do

        local fn=${build_steps[$i]}
        local status_msg="${build_neutral[$i]}"

        echo -n "${dm_build_msg[$i]} "

        if [ $status -eq 0 ]; then

            $fn

            if [ $? -ne 0 ]; then
                status_msg="${build_fail[$i]}"
                status=1
            else
                status_msg="${build_success[$i]}"
            fi
        fi

        echo_status_aligned "${dm_build_msg[$i]} " "$status_msg"

    done

    return $status
}

function print_usage
{
    echo "Usage: build_dm.sh [options]"
    echo
    echo "This script downloads, configures, and builds $dm_name so that it is"
    echo "ready to install for use with the $driver_name"
    echo
    echo "Valid options are --help, --download-url, --prefix, --libdir, --sysconfdir"
    echo "  --help - prints this message"
    echo "  --download-url=url | file:// - Specify the location (and name) of unixODBC-2.3.0.tar.gz."
    echo "       For example, if unixODBC-2.3.0.tar.gz is in the current directory, specify "
    echo "       --download-url=file://unixODBC-2.3.0.tar.gz."
    echo "  --prefix - directory to install $dm_package to."
    echo "  --libdir - directory where ODBC drivers will be placed"
    echo "  --sysconfdir - directory where $dm_name configuration files are placed"
    echo

    # prevent the script from continuing
    exit 0
}

function approve_download
{
    log "Accept the WARNING about download of unixODBC"

    if [ ! -f "./WARNING" ]; then
        log "WARNING file not found."
        echo "Cannot display download warning.  Please refer to the original archive for the"
        echo "WARNING file and then use the --accept-warning option to run this script."
        exit 1
    fi

    hash more &> /dev/null

    if [ $? -ne 0 ]; then
        log "more program not found. Cannot display the build warning without more."
        echo "Cannot display license agreement.  Please read the license agreement in LICENSE and"
        echo "re-run the install with the --accept-license parameter."
        exit 1
    fi

    more ./WARNING

    echo
    read -p "Enter 'YES' to have this script continue: " accept
    echo

    if [ "$accept" == "YES" ]; then
        log "Warning accepted"
        warning_accepted=1
        return 0
    fi

    log "Warning not accepted"
    echo "Exiting because warning not accepted"
    exit 1
}

echo
echo "Build $dm_name script"
echo "Copyright Microsoft Corp."
echo

while [ "$1" ]
do
    case "$1" in
        --download-url=*)
            dm_url=${1##--download-url=}
            log "$dm_name URL: $dm_url"
            ;;
        --prefix=*)
            prefixdir=${1##--prefix=}
            log "Installing $dm_name to $prefixdir"
            ;;
        --libdir=*)
            libdir=${1##--libdir=}
            log "Drivers configured to be place at $libdir"
            ;;
        --sysconfdir=*)
            sysconfdir=${1##--sysconfdir=}
            log "Configuration directory set to $sysconfdir"
            ;;
        --help)
            print_usage
            ;;
        --accept-warning)
            warning_accepted=1
            ;;
        *)
            echo "Unknown option $1"
            print_usage
            exit 1
            ;;
    esac
    shift
done

if [ $warning_accepted -ne 1 ]; then
    approve_download
fi

build $*

if [ $? -ne 0 ]; then
    echo "Errors occurred. See the $log_file file for more details."
    exit 1
fi

echo "Build of the $dm_name complete."
echo
echo "Run the command 'cd $tmp/$dm_dir; make install' to install the driver manager."
echo
echo "PLEASE NOTE THAT THIS WILL POTENTIALLY INSTALL THE NEW DRIVER MANAGER OVER ANY"
echo "EXISTING UNIXODBC DRIVER MANAGER.  IF YOU HAVE ANOTHER COPY OF UNIXODBC INSTALLED,"
echo "THIS MAY POTENTIALLY OVERWRITE THAT COPY."

exit 0
