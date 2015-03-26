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



function _depends(){
    which uuidgen 2>/dev/null >/dev/null
    if [ $? == 0 ]
    then
	export _uuid=`uuidgen`
    else
	echo "uuidgen not found"
	exit 1
    fi

    export _profiled="~/.mozilla/firefox"
    if [ ! -d ${_profiled} ]
    then
	export _profiled="~/.mozilla/Firefox"
	if [ ! -f ${_profiled}${_profile} ]
	then
	    echo "Unable to find firefox profile"
	    exit 1
	fi
    else
	if [ ! -f ${_profiled}${_profile} ]
	then
	    echo "Unable to find firefox profile"
	    exit 1
	fi
    fi
}

function _ramcreate(){
    export _ram="/tmp/${_uuid}"
    mkdir ${_ram}
    if [ -d ${_ram} ]
    then
	echo "Mounting ramdisk..."
	sudo mount -t tmpfs -o size=200M,mode=0777 none ${_ram}
    else
	echo "RAM directory unable to be created"
	exit 1
    fi
}

function _ramcopy(){
    export _image="Profiles/profile.tar.bz2"
    if [ -f "${_image}" ]
    then
	echo "Extracting..."
	tar --extract --bzip2 --file ${_image} --directory ${_ram}
    else
	echo "profile.tar.bz2 not found"
	exit 1
    fi
}

function _workramcopy(){
    if [ -d ${_work} ]
    then
	rsync -ri ${_work}/ ${_ram}/
    else
	echo "Work directory not found"
	exit 1
    fi 
}


function _createprofile(){
cat > ${_profiled}${_profile} <<EOF
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
    echo "Launching Firefox..."
    firefox -no-remote -P ${_uuid}
}





# main


_depends

if [ -z "$1" ]
then
    echo "Usage ramit.sh [work|ram]"
    echo ""
    echo "Prerequisit"
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
