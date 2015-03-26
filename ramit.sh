#!/bin/bash

#
# Firefox Profile in RAM
#


_uuid=
_image=
_profiled=
_profile=profiles.ini
_workd=work
_work="Profiles/work"
_worksave=


trap _cleanup SIGHUP SIGINT SIGTERM SIGQUIT


function _cleanup(){
    if [ "${_worksave}" == 1 ]
    then
	echo "Saving work..."
	rsync -ri ${_ram}/ ${_profiled}/${_work}/ --delete
	sudo umount firefast
	echo "Executed."
    fi
}


function _depends(){
    which uuidgen 2>/dev/null >/dev/null
    if [ $? == 0 ]
    then
	export _uuid=`uuidgen`
    else
	echo "uuidgen not found"
	exit 1
    fi

    export _profiled=~/.mozilla/firefox
    if [ ! -f ${_profiled}/${_profile} ]
    then
	export _profiled=~/.mozilla/Firefox
	if [ ! -f ${_profiled}/${_profile} ]
	then
	    echo "Unable to find firefox profile"

	fi
    fi
}

function _ramcreate(){
    export _ram="/tmp/${_uuid}"
    mkdir ${_ram}
    if [ -d ${_ram} ]
    then
	mount | grep "^firefast" 2>/dev/null >/dev/null
	if [ $? == 0 ]
	then
	    echo "Umounting existing ramdisk..."
	    i=`mount | grep "^firefast" | grep -c ".*"`
	    for (( i=${i}; i>0; i-- ))
	    do
		sudo umount -l firefast
	    done
	fi

	echo "Mounting ramdisk..."
	sudo mount -t tmpfs -o size=200M,mode=0777 firefast ${_ram}
    else
	echo "RAM directory unable to be created"
	exit 1
    fi
}

function _ramcopy(){
    export _image="Profiles/profile.tar.bz2"
    if [ -f "${_profiled}/${_image}" ]
    then
	echo "Extracting..."
	tar --extract --bzip2 --file ${_profiled}/${_image} --directory ${_ram}
    else
	echo "profile.tar.bz2 not found"
	exit 1
    fi
}

function _workramcopy(){
    if [ -d ${_profiled}/${_work} ]
    then
	export _worksave=1
	rsync -ri ${_profiled}/${_work}/ ${_ram}/
    else
	echo "Work directory not found"
	exit 1
    fi 
}


function _createprofile(){
cat > "${_profiled}/${_profile}" <<EOF
[Profile0]
Name=${_workd}
IsRelative=1
Path=${_work}

[Profile1]
Name=${_uuid}
IsRelative=0
Path=${_ram}
EOF
}


function _startfirefox(){
    echo "Accessing profile ${_uuid}"
    echo "Launching Firefox..."
    firefox -no-remote -P ${_uuid} 2>/dev/null >/dev/null
}





# main


_depends

if [ -z "$1" ]
then
    echo "Usage ramit.sh [work|ram]"
    echo ""
    echo "work	copy work profile to RAM, then run"
    echo "ram	copy template to RAM, then run"
    echo ""
    echo "Prerequisites:"
    echo " - Existing file: ~/.mozilla/firefox/profiles/profiles.ini"
    echo " - Existing profile archive: ~/.mozilla/firefox/profiles/profile.tar.bz2 (no root dir)"
    echo " - Existing work directory: ~/.mozilla/firefox/profiles/work"
    exit 1
fi

_ramcreate

if [ "$1" == "work" ]
then
    _workramcopy
fi

if [ "$1" == "ram" ]
then
    _ramcopy
fi

_createprofile
_startfirefox

read -p "Firefox ended unexpectedly..."
