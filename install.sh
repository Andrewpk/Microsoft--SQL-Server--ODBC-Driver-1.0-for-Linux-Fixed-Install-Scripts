#!/bin/bash
# Microsoft ODBC Driver 11 for SQL Server Installer
# Copyright Microsoft Corp.

# Set to 1 for debugging information/convenience.
debug=0

# Strings listed here
driver_name="Microsoft ODBC Driver 11 for SQL Server";
driver_version="11.0.2270.0"
driver_dm_name="ODBC Driver 11 for SQL Server"
driver_short_name="msodbcsql"


# Requirements listed here
req_os="Linux";
req_proc="x86_64";
req_dm_ver="2.3.2";
dm_name="unixODBC $req_dm_ver";
os_dist_id=`lsb_release -is`
is_this_debian_based="/etc/debian_version"

req_libs=""
real_deb_req_libs=( "libc6" "libkrb5-3" "e2fsprogs" "openssl" )

#this should get renamed to ubuntu_req_libs or something 
deb_req_libs=( '~i"^libc6$"' '~i"libkrb5\-[0-9]$"' '~i"^e2fsprogs$"' '~i"^openssl$"' )

red_req_libs=( glibc e2fsprogs krb5-libs openssl )

if [ $os_dist_id == "Ubuntu" ] || [ $os_dist_id == "Debian" ] || [ $os_dist_id == "LinuxMint" ] || [ -e "$is_this_debian_based" ]; then
    hash aptitude &> /dev/null
    has_aptitude=$?
    if [ $os_dist_id == "Ubuntu" ] || [ $os_dist_id == "LinuxMint" ] || [ $has_aptitude -eq 0 ]; then
        req_libs=("${deb_req_libs[@]}")
    else
        req_libs=("${real_deb_req_libs[@]}")
    fi
else
    req_libs=("${red_req_libs[@]}")
fi

#language of the install
lang_id="en_US";

# files to be copied by directory
driver_file="libmsodbcsql-11.0.so.2270.0"

lib_files=( "lib64/$driver_file" )
lib_perms=( 0755 )

bin_files=( "bin/bcp-11.0.2270.0"
            "bin/sqlcmd-11.0.2270.0" )
bin_sym=( bcp sqlcmd )
bin_perms=( 0755 0755 )

sup_files=( install.sh build_dm.sh README LICENSE WARNING )
sup_perms=( 0755 0755 0644 0644 0644 )

rll_files=( "bin/bcp.rll"
            "bin/SQLCMD.rll"
            "bin/BatchParserGrammar.dfa"
            "bin/BatchParserGrammar.llr"
            "lib64/msodbcsqlr11.rll" )
rll_perms=( 0644 0644 0644 0644 0644 )

doc_files=( "docs/en_US.tar.gz" )
doc_perms='$(printf "0644 %.0s" {1..'${#doc_files[@]}'})'
doc_perms=( $(eval "echo $doc_perms") )

inc_files=( "include/msodbcsql.h" )
inc_perms='$(printf "0644 %.0s" {1..'${#inc_files[@]}'})'
inc_perms=( $(eval "echo $inc_perms") )

dirs=( bin_dir lib_dir sup_dir rll_dir doc_dir inc_dir )
sym_dirs=( bin_sym_dir lib_sym_dir sup_sym_dir rll_sym_dir doc_sym_dir inc_sym_dir )
file_sets=( bin_files lib_files sup_files rll_files doc_files inc_files )
link_sets=( bin_sym "null" "null" "null" "null" "null" )
file_perm_sets=( bin_perms lib_perms sup_perms rll_perms doc_perms inc_perms )
link_perm_sets=( bin_perms lib_perms sup_perms rll_perms doc_perms inc_perms )

# "assertions" that the file and sym link arrays are sane
if [ ${#lib_files[@]} -ne ${#lib_perms[@]} ]; then
    echo "Lib files and permission sets don't match"
    exit 1;
fi
if [ ${#bin_files[@]} -ne ${#bin_sym[@]} ]; then
    echo "Bin files and sym links don't match"
    exit 1;
fi
if [ ${#bin_files[@]} -ne ${#bin_perms[@]} ]; then
    echo "Bin files and permission sets don't match"
    exit 1;
fi
if [ ${#sup_files[@]} -ne ${#sup_perms[@]} ]; then
    echo "Supplemental files and permission sets don't match"
    exit 1;
fi
if [ ${#rll_files[@]} -ne ${#rll_perms[@]} ]; then
    echo "RLL files and permission sets don't match"
    exit 1;
fi
if [ ${#dirs[@]} -ne ${#file_sets[@]} ]; then
    echo "Directories and file sets don't match"
    exit 1;
fi
if [ ${#file_sets[@]} -ne ${#link_sets[@]} ]; then
    echo "File and link sets don't match"
    exit 1;
fi
if [ ${#file_sets[@]} -ne ${#file_perm_sets[@]} ]; then
    echo "File and permission sets don't match"
    exit 1;
fi
if [ ${#link_sets[@]} -ne ${#link_perm_sets[@]} ]; then
    echo "Link and permission sets don't match"
    exit 1;
fi
if [ ${#doc_files[@]} -ne ${#doc_perms[@]} ]; then
    echo "Doc files and permission sets don't match"
    exit 1;
fi
if [ ${#inc_files[@]} -ne ${#inc_perms[@]} ]; then
    echo "Include files and permission sets don't match"
    exit 1;
fi

# directories to hold the file categories
bin_dir="";
lib_dir="";
sup_dir="/opt/microsoft/$driver_short_name/$driver_version";
rll_dir="";
doc_dir="";
inc_dir="";

# Force installation flag (--force parameter) default is not to force
force=0

# Accept the license flag (--accept-license) default is that they must accept the license via a prompt
license_accepted=0

# Log file in the temp directory
tmp=${TMPDIR-/tmp}
tmp="$tmp/$driver_short_name.$RANDOM.$RANDOM.$RANDOM"
(umask 077 && mkdir $tmp) || {
    echo "Could not create temporary directory for the log file." 2>&1
    exit 1
}
log_file=$tmp/install.log

# for debugging purposes
[ $debug -eq 1 ] && log_file="install.log"
[ $debug -eq 1 ] && rm -f install.log

echo
echo "$driver_name Installation Script"
echo "Copyright Microsoft Corp."
echo
echo "Starting install for $driver_name"
echo


function print_usage()
{
    echo "Usage: install.sh [global options] command [command options]"
    echo
    echo "Global options:"
    echo "   --help - prints this message"
    echo "Valid commands are verify and install"
    echo "  install) install the driver (also verifies before installing and registers"
    echo "           with the driver manager)"
    echo "  verify) check to make sure the unixODBC DriverManager configuration is"
    echo "          correct before installing"
    echo "install command take the following options:"
    echo "  --bin-dir=<directory> - location to create symbolic links for bcp and sqlcmd utilities,"
    echo "      defaults to the /usr/bin directory"
    echo "  --lib-dir=<directory> - location to deposit the Microsoft SQL Server ODBC Driver for Linux,"
    echo "      defaults to the /opt/microsoft/msodbcsql/lib directory"
    echo "  --force - continues installation even if an error occurs"
    echo "  --accept-license - forgoes showing the EULA and implies agreement with its contents"
    echo "  --force-debian - forces the install to continue as a debian based/compatible linux distribution"
    echo "  --force-ubuntu - forces the install to continue as a ubuntu based/compatible linux distribution"
    echo "  --force-redhat - forces the install to continue as a redhat based/compatible linux distribution"
    echo

    # don't return if we're printing the usage
    exit 0;
}

function log()
{
    local msg=$*;
    local date=$(date);
    echo "["$date"]" $msg >> $log_file
}

# format a message and status for an 80 character terminal
function format_status
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

    local full_msg="$msg $(expr substr "$dots" 1 $dot_count) $status"
    echo $full_msg

    return 0
}

function report_config()
{
    format_status "Checking for 64 bit Linux compatible OS" "$1"
    format_status "Checking required libs/locale(en_US.utf8) are installed" "$2"
    format_status "unixODBC utilities (odbc_config and odbcinst) installed" "$3"
    format_status "unixODBC Driver Manager version $req_dm_ver installed" "$4"
    format_status "unixODBC Driver Manager configuration correct" "$5"
    format_status "$driver_name already installed" "$6"
}

# verify that the installation is on a 64 bit OS
function check_for_Linux_x86_64 ()
{
    log "Verifying on a 64 bit Linux compatible OS"
    local proc=$(uname -m);
    # bash string bugs: http://www.tldp.org/LDP/abs/html/comparison-ops.html
    if [[ "x$proc" != "x$req_proc" ]]; then
        log "This installation of the $driver_name may only be installed"
        log "on a 64 bit Linux compatible operating system."
        return 1;
    fi

    local os=$(uname -s);
    if [ $os != $req_os ]; then
        log "This installation of the $driver_name may only be installed"
        log "on a 64 bit Linux compatible operating system."
        return 1;
    fi

    return 0;
}

# verify required locale is present
function check_required_locale
{
    log "Checking that required locales are installed"
    has_en_utf8_locale=$(locale -a | grep "en_US.utf8")
    if [ -z ${has_en_utf8_locale} ]; then
        log "The en_US.utf8 locale is required. Please add the locale to your system before continuing."
        log "Adding locales can be as simple as 'sudo locale-gen en_US.utf8 && sudo dpkg-reconfigure locales'."
        log "Please see your distribution's manual for more details regarding adding locales."
        return 1;
    fi
}

# verify that the required libs are on the system
function check_required_libs
{
    log "Checking that required libraries are installed"

    for lib in ${req_libs[@]}
    do
        hash rpm &> /dev/null
        has_rpm=$?
        hash aptitude &> /dev/null
        has_aptitude=$?
        hash dpkg &> /dev/null
        has_dpkg=$?
        local present=""
        if [ $has_rpm -eq 0 ]; then
            log "Checking for $lib"
            present=$(rpm -q -a $lib) >> $log_file 2>&1
        elif [ $has_aptitude -eq 0 ]; then
            log "Checking for $lib"
            present=$(aptitude search $lib ) >> $log_file 2>&1
        elif [ $has_dpkg -eq 0 ]; then
            present=$(dpkg --get-selections $lib ) >> $log_file 2>&1
        fi
        if [ "$present" == "" ]; then
            log "The $lib library was not found installed in the RPM database."
            log "See README for which libraries are required for the $driver_name."
            return 1;
        fi
    done

    return 0;
}

# verify that the driver manager utilities are runnable so we may
# check the configuration and install the driver.
function find_odbc_config ()
{
    log "Verifying if unixODBC is present"
    # see if odbc_config is installed
    hash odbc_config &> /dev/null
    if [ $? -eq 1 ]; then
        log "odbc_config from unixODBC was not found.  It is required to properly install the $driver_name";
        return 1;
    fi

    hash odbcinst &> /dev/null
    if [ $? -eq 1 ]; then
        log "odbcinst from unixODBC was not found.  It is required to properly install the $driver_name";
        return 1;
    fi

    return 0;
}

function is_already_installed()
{
    log "Checking if $driver_name is already installed in $dm_name"
    odbcinst -q -d -n "$driver_dm_name" -v >> $log_file
    if [ $? -eq 0 ]; then
        log "The $driver_name is already installed."
        log "Use --force to reinstall the driver again.";
        return 1;
    fi

    return 0;
}

function verify_dm_version ()
{
    log "Verifying that unixODBC is version $req_dm_ver"

    # verify version
    local version=$(odbc_config --version);
    if [ $? -ne 0 ]; then
        log "Cannot determine version of installed unixODBC.";
        return 1;
    fi
    local maj_ver_num=`echo $version | cut -d'.' -f1`
    local min_ver_num=`echo $version | cut -d'.' -f2`
    local pat_ver_num=`echo $version | cut -d'.' -f3`
    if [ "$maj_ver_num" -eq "2" ] && [ "$min_ver_num" -ge "3" ] && [ "$pat_ver_num" -ge "0" ]; then
        log "unixODBC version is >= 2.3.0";
    else
        log "unixODBC version must be" $req_dm_ver ".  See README for more information.";
        return 1;
    fi

    return 0;
}

function verify_dm_config()
{
    local config=$(odbc_config --cflags)

    local sizeof_long_int=${config/SIZEOF_LONG_INT\=8/}
    local legacy_64bit_mode=${config/BUILD_LEGACY_64_BIT_MODE/}

    # configuration must have this flag set, so it should be deleted from sizeof_long_int
    if [ "$config" == "$sizeof_long_int" ]; then
        log "unixODBC must have the configuration SIZEOF_LONG_INT=8."
        log "This will probably require a rebuild of the unixODBC Driver Manager."
        log "See README for more information."
        return 1;
    fi

    # configuration shouldn't have this flag set, so it should not be deleted (be the same)
    if [ "$config" != "$legacy_64bit_mode" ]; then
        log "unixODBC must not have BUILD_LEGACY_64_BIT_MODE configuration flag set."
        log "This will probably require a rebuild of the unixODBC Driver Manager."
        log "See README for more information."
        return 1;
    fi

    return 0;
}


# verify all configuration prerequisites and print the status of each.
# 0 means all checks pass, 1 means one or more items has failed

function verify_config
{
    local proc_os_okay="NOT CHECKED"
    local locale_installed="NOT CHECKED"
    local libs_installed="NOT CHECKED"
    local odbc_config="NOT CHECKED"
    local already_installed="NOT CHECKED"
    local version_dm_okay="NOT CHECKED"
    local dm_config_okay="NOT CHECKED"

    verify_steps=( check_for_Linux_x86_64 check_required_locale check_required_libs find_odbc_config verify_dm_version verify_dm_config is_already_installed )
    verify_status_vars=( proc_os_okay locale_installed libs_installed odbc_config version_dm_okay dm_config_okay already_installed )
    verify_success=( 'OK' 'OK' 'OK' 'OK' 'OK' 'OK*' 'NOT FOUND' )
    verify_fail=( 'FAILED' 'NOT FOUND' 'NOT FOUND' 'FAILED' 'FAILED' 'FAILED' 'INSTALLED' )

    if [ ${#verify_steps[@]} -ne ${#verify_status_vars[@]} ]; then
        echo "Error in verify script 1"
        exit 1;
    fi
    if [ ${#verify_steps[@]} -ne ${#verify_success[@]} ]; then
        echo "Error in verify script 2"
        exit 1;
    fi
    if [ ${#verify_steps[@]} -ne ${#verify_fail[@]} ]; then
        echo "Error in verify script 3"
        exit 1;
    fi

    local i=0

    for (( i = 0 ; i < ${#verify_steps[@]} ; i++ ))
    do
        local fn=${verify_steps[$i]}
        local status_var=${verify_status_vars[$i]}

        eval $status_var="\"${verify_success[$i]}\""

        $fn
        if [ $? -ne 0 ]; then
            if [ $force -ne 1 ]; then
               status=1;
            fi
            eval $status_var="\"${verify_fail[$i]}\""
            break
        fi

    done

    report_config "$proc_os_okay" "$locale_installed" "$libs_installed" "$odbc_config" "$version_dm_okay" "$dm_config_okay" "$already_installed"

    return $status
}

# installation

function copy_files
{
    log "Copying files"

    local i=0

    for (( i = 0 ; i < ${#dirs[@]} ; i++ ))
    do
        local dir="${dirs[$i]}"
        local files="${file_sets[$i]}"
        local perms="${file_perm_sets[$i]}"

        # evaluate the contents of the variables and assign them back
        eval dir=\$$dir
        eval files=\(\$\{$files\[\@\]\}\)
        eval perms=\(\$\{$perms\[\@\]\}\)

        mkdir -p $dir

        local j=0

        for (( j = 0; j < ${#files[@]}; j++ ))
        do

            local f=${files[$j]}
            local p=${perms[$j]}

            log "Copying $f to $dir"
            cp $f $dir >> $log_file 2>&1

            if [ $? -ne 0 ]; then
                log "Failed to copy $f to $dir."
                if [ $force -ne 1 ]; then
                    return 1;
                fi
            fi

            f=${f##*/}
            log "Setting permissions on $f"
            chmod $p $dir/$f >> $log_file 2>&1

            if [ $? -ne 0 ]; then
                log "Failed to set the permission of $f to $p."
                if [ $force -ne 1 ]; then
                    return 1;
                fi
            fi

        done
    done

    return 0;
}

# it tries to remove all the files regardless of the outcome of a removal,
# as such it always returns 0 for "success"
function remove_files
{
    log "Removing files"

    local i=0

    for (( i = 0 ; i < ${#dirs[@]} ; i++ ))
    do
        local dir="${dirs[$i]}"
        local files="${file_sets[$i]}"
        local links="${link_sets[$i]}"

        # evaluate the contents of the variables and assign them back
        eval dir=\$$dir
        eval files=\( \$\{$files\[\@\]\} \)
        eval links=\( \$\{$links\[\@\]\} \)

        for l in ${links[@]}
        do
            [ "$l" == "null" ] && continue

            log "Removing $dir/$l"
            rm -f $dir/$l >> $log_file 2>&1

            if [ $? -ne 0 ]; then
                log "Non fatal error: Failed to remove $l to $dir."
            fi
        done

        for f in ${files[@]}
        do
            log "Removing $dir/$f"
            rm -f $dir/$f >> $log_file 2>&1

            if [ $? -ne 0 ]; then
                log "Non fatal error: Failed to remove $f to $dir."
            fi
        done
    done

    return 0;
}

function register_driver
{
    log "Registering the $driver_name driver"

    # write INI file for driver installation in the temp directory
    local template_ini="$tmp/$driver_short_name.ini"

    # for debugging purposes
    [ $debug -eq 1 ] && template_ini="$driver_short_name.ini"

    echo "[$driver_dm_name]" > $template_ini
    echo "Description = $driver_name" >> $template_ini
    echo "Driver = $lib_dir/$driver_file" >> $template_ini
    echo "Threading = 1" >> $template_ini
    echo "" >> $template_ini

    if [ $? -ne 0 ]; then
        log "Failed to create ini file $template_ini used to install the driver"
        return 1;
    fi

    # install the driver using odbcinst
    odbcinst -i -d -f "$template_ini" 2>&1 >> $log_file

    if [ $? -ne 0 ]; then
        log "Failed installing driver $driver_name with $dm_name"
        return 1;
    fi

    # copy the template ini file to the supplemental directory
    cp $template_ini $sup_dir 2>> $log_file

    if [ $? -ne 0 ]; then
        log "Warning: $template_ini could not be copied to $sup_dir"
    fi

    return 0;
}

function extract_docs
{
    local doc_file="$doc_dir/$lang_id.tar.gz"

    log "Extracting documentation from $doc_file"

    local cwd=$(pwd)

    cd $doc_dir
    if [ $? -ne 0 ]; then
        log "Couldn't enter the directory $doc_dir to extract documentation."
        return 1
    fi

    tar xvzf $doc_file 2>&1 >> $log_file
    if [ $? -ne 0 ]; then
        log "Couldn't extract documentation from $doc_file"
        return 1
    fi

    rm $doc_file 2>&1 >> $log_file
    if [ $? -ne 0 ]; then
        log "Couldn't erase documentation archive after extraction"
        return 1
    fi

    return 0;
}

function create_symlinks
{
    log "Creating symbolic links"

    local i=0
    local j=0

    for (( i = 0 ; i < ${#dirs[@]} ; i++ ))
    do
        local dir="${dirs[$i]}"
        local sym_dir="${sym_dirs[i]}"
        local files="${file_sets[$i]}"
        local links="${link_sets[$i]}"

        [ "$links" == "null" ] && continue

        # evaluate the contents of the variables and assign them back
        eval dir=\$$dir
        eval sym_dir=\$$sym_dir
        eval files=\( \$\{$files\[\@\]\} \)
        eval links=\( \$\{$links\[\@\]\} \)

        # assertion that the links and files are the same length
        if [ ${#files[@]} -ne ${#links[@]} ]; then
            log "Fatal: file and link lists do not match."
            exit 1;
        fi

        # if there is no symbolic link dir, then there are no symlinks
        [ "$sym_dir" == "" ] && continue

        local j=0

        for (( j = 0 ; j < ${#files[@]} ; j++ ))
        do
            local f="${files[$j]##*/}"
            local l="${links[$j]}"

            #if the "link" is null, then skip it
            [ "$l" == "null" ] && continue

            if [ $force -ne 0 ]; then
                log "Removing previous link due to force flag"
                rm $sym_dir/$l >> $log_file 2>&1
            fi

            log "Linking $l to $f"
            ln -s $dir/$f $sym_dir/$l >> $log_file 2>&1

            if [ $? -ne 0 ]; then
                log "Failed to link $l to $f."
                if [ $force -ne 1 ]; then
                    return 1;
                fi
            fi
        done
    done
	
    # This has been tested in Ubuntu 12.04 and 14.04 LTS
    log "Creating symlinks needed in Ubuntu."
    hash aptitude &> /dev/null
   	local has_aptitude=$?
    hash dpkg &> /dev/null
    local has_dpkg=$?
    local deb_os_id=$(cat /etc/debian_version);
    local os_id=$(lsb_release -si);

    if [ $has_aptitude -eq 0 ] && [ "$os_id" == "Ubuntu" ]; then
        if [ $force -eq 1 ]; then
            if [ -h /usr/lib/x86_64-linux-gnu/libcrypto.so.10 ]; then
                rm /usr/lib/x86_64-linux-gnu/libcrypto.so.10;
            fi
            if [ -h /usr/lib/x86_64-linux-gnu/libssl.so.10 ]; then
                rm /usr/lib/x86_64-linux-gnu/libssl.so.10;
            fi
            if [ -h /usr/lib/x86_64-linux-gnu/libodbcinst.so.1 ]; then
                rm /usr/lib/x86_64-linux-gnu/libodbcinst.so.1;
            fi
            if [ -h /usr/lib/x86_64-linux-gnu/libodbc.so.1 ]; then
                rm /usr/lib/x86_64-linux-gnu/libodbc.so.1;
            fi
        fi
        ln -s /lib/x86_64-linux-gnu/libcrypto.so.1.0.0 /usr/lib/x86_64-linux-gnu/libcrypto.so.10 >> $log_file 2>&1;
        ln -s /lib/x86_64-linux-gnu/libssl.so.1.0.0 /usr/lib/x86_64-linux-gnu/libssl.so.10 >> $log_file 2>&1;
        if [ -f /usr/lib/x86_64-linux-gnu/libodbcinst.so.2.0.0 ]; then
            ln -s /usr/lib/x86_64-linux-gnu/libodbcinst.so.2.0.0 /usr/lib/x86_64-linux-gnu/libodbcinst.so.1 >> $log_file 2>&1;
        else
            log "proper libodbcinst.so not found. You will need to create the symlink manually"
        fi
        if [ -f /usr/lib/x86_64-linux-gnu/libodbc.so.2.0.0 ]; then
            ln -s /usr/lib/x86_64-linux-gnu/libodbc.so.2.0.0 /usr/lib/x86_64-linux-gnu/libodbc.so.1 >> $log_file 2>&1;
        else
            log "proper libodbc.so not found. You will need to create the symlink manually"
        fi
    elif [ $has_dpkg -eq 0 ] && [ "$deb_os_id" == "8.1" ] ; then
        if [ $force -eq 1 ]; then
            if [ -h /usr/lib/x86_64-linux-gnu/libcrypto.so.10 ]; then
                rm /usr/lib/x86_64-linux-gnu/libcrypto.so.10;
            fi
            if [ -h /usr/lib/x86_64-linux-gnu/libssl.so.10 ]; then
                rm /usr/lib/x86_64-linux-gnu/libssl.so.10;
            fi
            if [ -h /usr/lib/x86_64-linux-gnu/libodbcinst.so.1 ]; then
                rm /usr/lib/x86_64-linux-gnu/libodbcinst.so.1;
            fi
            if [ -h /usr/lib/x86_64-linux-gnu/libodbc.so.1 ]; then
                rm /usr/lib/x86_64-linux-gnu/libodbc.so.1;
            fi
        fi
        ln -s /usr/lib/x86_64-linux-gnu/libcrypto.so.1.0.0 /usr/lib/x86_64-linux-gnu/libcrypto.so.10 >> $log_file 2>&1;
        ln -s /usr/lib/x86_64-linux-gnu/libssl.so.1.0.0 /usr/lib/x86_64-linux-gnu/libssl.so.10 >> $log_file 2>&1;
        if [ -f /usr/lib/x86_64-linux-gnu/libodbcinst.so.2.0.0 ]; then
            ln -s /usr/lib/x86_64-linux-gnu/libodbcinst.so.2.0.0 /usr/lib/x86_64-linux-gnu/libodbcinst.so.1 >> $log_file 2>&1;
        else
            log "proper libodbcinst.so not found. You will need to create the symlink manually"
        fi
        if [ -f /usr/lib/x86_64-linux-gnu/libodbc.so.2.0.0 ]; then
            ln -s /usr/lib/x86_64-linux-gnu/libodbc.so.2.0.0 /usr/lib/x86_64-linux-gnu/libodbc.so.1 >> $log_file 2>&1;
        else
            log "proper libodbc.so not found. You will need to create the symlink manually"
        fi
    else
        SCRIPTPATH=$( cd "$(dirname "$0")" ; pwd -P )
        log "You need to create some symlinks manually. Use the following command to find out more:"
        log "ldd $SCRIPTPATH/lib64/libmsodbcsql-11.0.so.2270.0"
    fi

    return 0;
}

function report_install()
{
    format_status "$driver_name files copied" "$1"
    format_status "Symbolic links for bcp and sqlcmd created" "$2"
    format_status "$driver_name registered" "$3"
}

function process_params
{
    # process parameters
    while [ "$1" ]
    do
        case "$1" in
            --force)
                force=1
                ;;
            --force-ubuntu)
                req_libs=("${deb_req_libs[@]}")
                ;;
            --force-debian)
                req_libs=("${real_deb_req_libs[@]}")
                ;;
            --force-redhat)
                req_libs=("${red_req_libs[@]}")
                ;;
            --bin-dir=*)
                bin_sym_dir=${1##--bin-dir=}
                bin_sym_dir=${bin_sym_dir/#"~"/$HOME}
                log "Symbolic links to binaries created in $bin_sym_dir"
                ;;
            --lib-dir=*)
                lib_dir=${1##--lib-dir=}
                lib_dir=${lib_dir/#"~"/$HOME}
                log "Driver directory set to $lib_dir"
                ;;
            --accept-license)
                license_accepted=1
                log "License agreement accepted"
                ;;
            *)
                echo "Unknown parameter $1"
                print_usage
                exit 1
                ;;
        esac

        shift
    done

    return 0
}

function accept_license
{
    log "Accept the license agreement"

    if [ ! -f "./LICENSE" ]; then
        log "LICENSE file not found."
        echo "Cannot display license agreement.  Please refer to the original archive for the"
        echo "LICENSE file and re-run the install with the --accept-license parameter."
        exit 1
    fi

    hash more &> /dev/null

    if [ $? -ne 0 ]; then
        log "more program not found. Cannot display license agreement without more."
        echo "Cannot display license agreement.  Please read the license agreement in LICENSE and"
        echo "re-run the install with the --accept-license parameter."
        exit 1
    fi

    more ./LICENSE

    echo
    read -p "Enter YES to accept the license or anything else to terminate the installation: " accept
    echo

    if [ "$accept" == "YES" ]; then
        log "License agreement accepted"
        license_accepted=1
        return 0
    fi

    log "License agreement not accepted"
    return 1
}

function install()
{
    # return value
    local status=0

    process_params $*

    if [ $license_accepted -ne 1 ]; then
        accept_license
    fi

    # technically accept_license should not return if the license isn't accepted,
    # but this is a catch for it
    if [ $? -ne 0 ] || [ $license_accepted -ne 1 ]; then
        return 1
    fi

    verify_config

    local verified=$?

    local files_copied="NOT ATTEMPTED"
    local docs_extracted="NOT ATTEMPTED"
    local driver_registered="NOT ATTEMPTED"
    local symlinks_created="NOT ATTEMPTED"

    # if verification passed or force was specified, then call the functions to install
    # and register the driver
    if [ $verified -eq 0 ] || [ $force -eq 1 ]; then

        if [ "$lib_dir" == "" ]; then
            lib_dir="/opt/microsoft/$driver_short_name/lib64"
        fi

        bin_dir="/opt/microsoft/$driver_short_name/bin"

        if [ "$bin_sym_dir" == "" ]; then
            bin_sym_dir="/usr/bin";
        fi

        sup_dir="/opt/microsoft/$driver_short_name/$driver_version"
        mkdir -p $sup_dir
        if [ -d $sup_dir ]; then
            log "$sup_dir exists"
        else
            log "Could not create $sup_dir"
            return 1
        fi

        rll_dir="$sup_dir/$lang_id"
        mkdir -p $rll_dir
        if [ -d $rll_dir ]; then
            log "$rll_dir exists"
        else
            log "Could not create $rll_dir"
            return 1
        fi

        doc_dir="$sup_dir/docs/$lang_id"
        mkdir -p $doc_dir
        if [ -d $doc_dir ]; then
            log "$doc_dir exists"
        else
            log "Could not create $doc_dir"
            return 1
        fi

        inc_dir="$sup_dir/include"
        mkdir -p $inc_dir
        if [ -d $inc_dir ]; then
            log "$inc_dir exists"
        else
            log "Could not create $inc_dir"
            return 1
        fi

        local install_steps=( copy_files extract_docs create_symlinks register_driver )
        local install_status_vars=( files_copied docs_extracted symlinks_created driver_registered )
        local install_success=( 'OK' 'OK' 'OK' 'INSTALLED' )
        local install_fail=( 'FAILED' 'FAILED' 'FAILED' 'FAILED' )

        # "assertions" that the variables are sane
        if [ ${#install_steps[@]} -ne ${#install_status_vars[@]} ]; then
            echo "Error in install script 1"
            exit 1;
        fi
        if [ ${#install_steps[@]} -ne ${#install_success[@]} ]; then
            echo "Error in install script 2"
            exit 1;
        fi
        if [ ${#install_steps[@]} -ne ${#install_fail[@]} ]; then
            echo "Error in install script 3"
            exit 1;
        fi

        local i=0

        for (( i = 0 ; i < ${#install_steps[@]} ; i++ ))
        do
            local fn=${install_steps[$i]}
            local status_var=${install_status_vars[$i]}

            eval $status_var="\"${install_success[$i]}\""

            $fn

            if [ $? -ne 0 ]; then
                status=1
                eval $status_var="\"${install_fail[$i]}\""
                if [ $force -ne 1 ]; then
                    uninstall
                    break
                fi
            fi
        done
    fi

    report_install "$files_copied" "$symlinks_created" "$driver_registered"

    return $status
}

function uninstall
{
    process_params $*

    return 0;
}

command=$1
shift

case "$command" in
    install)
        install $*
        ;;
    verify)
        verify_config $*
        ;;
    --help)
        print_usage
        ;;
    *)
        echo "Unknown command given."
        print_usage
        ;;
esac

# if any problems, print out a final diagnostic about where to find failure reasons
# and exit with status of 1
if [ $? -ne 0 ]; then
    echo
    echo "See $log_file for more information about installation failures."
    exit 1
fi

echo
echo "Install log created at $log_file."
echo
echo "One or more steps may have an *. See README for more information regarding"
echo "these steps."

# return success
exit 0
