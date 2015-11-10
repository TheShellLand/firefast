#!/bin/bash

#
# Firefox Profile in RAM
#

# Version: 2.1
#
# Change Log:
#   - Added option for firefox nightly
#   - Added option for creating new work image
#   - Added option for recovering work profile from work image
#



_uuid=
_image=
_profiled=
_profile=profiles.ini
_workd=work
_work="profiles/work"
_worksave=
_workimage=
_golden=
_ram=
_keeper=
firefox_build=


trap _cleanup SIGHUP SIGINT SIGTERM SIGQUIT



function _depends(){
    which uuidgen 2>/dev/null >/dev/null
    if [ $? == 0 ]
    then export _uuid=`uuidgen`
    else echo "[Error] uuidgen not found"
	 exit 1; fi

    export _profiled=~/.mozilla/firefox
    if [ ! -f ${_profiled}/${_profile} ]
    then export _profiled=~/.mozilla/firefox
	 if [ ! -f ${_profiled}/${_profile} ]
	 then echo "[Error] Unable to find firefox profile"; fi; fi
}


function _existingRun(){
    export _keeper=0

    pidof firefox 2>/dev/null >/dev/null
    if [ $? == 0 ]
    then echo "[*] Firefox is already running"
	 pidof -x $0 2>/dev/null >/dev/null
	 if [ $? == 0 ]
	 then echo "[*] Program already running. Spawning new process"
	      export _keeper=1
	      return 0; fi; fi
}


function _ramcreate(){
    export _ram="/dev/shm/firefast/${_uuid}"
    echo "[*] Creating RAMDISK ..."
    mkdir -p ${_ram} || (echo "[Failed]"; exit 1)
}

function _ramcopy(){
    export _image="profiles/robot.tar.gz"
    if [ -f "${_profiled}/${_image}" ]
    then echo "[*] Extracting image ..."
	 tar --extract --gzip --file ${_profiled}/${_image} --directory ${_ram} || (echo "[Failed]"; exit 1)
	 return 0
    else echo "[Error] $_image not found"
	 exit 1; fi
}

function _workramcopy(){
    if [ "$1" == "bad" ]
    then export _workimage="profiles/work.tar.gz"
	 if [ -f "${_profiled}/${_workimage}" ]
	 then echo "[*] Deleting old files ..."
	      rm -rf "${_profiled}/${_work}/*" || (echo "[Failed]"; exit 1)
	      echo "[*] Extracting files ..."
	      tar --extract --gzip --file ${_profiled}/${_workimage} --directory ${_profiled}/${_work} || (echo "[Failed]"; exit 1)
	 else echo "[Error] Restore from work image failed"
	      echo "[Error] Work image not found"; exit 1; fi; fi
    
    if [ -d "${_profiled}/${_work}" ]
    then 
	export _worksave=1
	echo "[*] Copying to RAM ..."
	rsync -r ${_profiled}/${_work}/ ${_ram}/ || (echo "[Failed]"; exit 1)
	return 0
    else echo "[Error] Work directory not found"
	 exit 1; fi
}



function _createprofile(){ 
cat > "${_profiled}/${_profile}" <<EOF
[General]
StartWithLastProfile=0

[Profile0]
Name=${_workd}
IsRelative=0
Path=${_ram}
Default=0

[Profile1]
Name=${_uuid}
IsRelative=0
Path=${_ram}
Default=0
EOF

return 0
}


function _startfirefox(){ 
    echo "[*] Accessing profile ${_uuid}"
    echo "[*] Launching Firefox ..."

    # Choose between firefox and firefox-nightly
    if [ "$1" == regular ]; then
        # Regular firefox
        firefox -no-remote -P ${_uuid} 2>/dev/null >/dev/null; fi

    if [ "$1" == nightly ]; then
        # Nightly build of firefox (has multi-process support)
        firefox-nightly -no-remote -P ${_uuid} 2>/dev/null >/dev/null; fi

    echo "[*] Firefox closed"
    _cleanup
    exit 0
}



function _cleanup(){
    if [ "$_worksave" == 1 ]
    then echo "[*] Saving work ..."
	 rsync -rh ${_ram}/ ${_profiled}/${_work}/ --delete || (echo "[Failed]"; exit 1)
	 echo "[*] Releasing memory ..."
	 rm -rf ${_ram} || (echo "[Failed]"; exit 1)
	 echo "[*] Executed"
	 return 0; fi

    if [ "$_golden" == 1 ]
    then echo "[*] Creating gold image ..."

	 if [ -d ${_ram} ]
	 then if [ -d ${_profiled}/${_work} ]
	      then if [ -f ${_profiled}/${_image} ]
		   then cd ${_ram}
			tar --create --gzip --file ${_profiled}/${_image} * || (echo "[Failed]"; exit 1)
			echo "[*] Releasing memory ..."
			rm -rf ${_ram} || (echo "[Failed]"; exit 1)
			return 0
		   else echo "[Error] Existing gold image not found"
			exit 1; fi
		   echo "[*] Executed"
	      else echo "[Error] Work profile not found"
		   exit 1; fi
	 else echo "[Error] Ramdisk not found"
	       exit 1; fi; fi

    if [ "$_newram" == 1 ]; then
        echo "[*] Creating ram image ..."
        if [ -d ${_ram} ]; then
            if [ -f ${_profiled}/${_image} ]; then
                cd ${_ram}
                tar --create --gzip --file ${_profiled}/${_image} * || (echo "[Failed]"; exit 1)
                echo "[*] Releasing memory ..."
                rm -rf ${_ram} || (echo "[Failed]"; exit 1)
                return 0
    fi; fi; fi
}





# main


_depends
_existingRun

if [ -z "$1" ]
then echo "Usage ramit.sh <option> <regular|nightly>"
     echo ""
     echo "	work    copy work profile to RAM, then run"
     echo "	ram copy template to RAM, then run"
     echo ""
     echo "Additional Options:"
     echo ""
     echo "	gold	copy work template to RAM, then create gold image"
     echo "	bad	restore from work template, then run work"
     echo "	new	copy ram template to RAM, then create new ram image"
     echo ""
     echo ""
     echo " [Required] Existing file: ~/.mozilla/firefox/profiles/profiles.ini"
     echo " [Required] Existing profile archive: ~/.mozilla/firefox/profiles/robot.tar.gz (no root dir)"
     echo " [Required] Existing work directory: ~/.mozilla/firefox/profiles/work"
     exit 1; fi

_ramcreate

if [ ! -z "$2" ]
then export firefox_build="$2"
    if [ "$firefox_build" == nightly ]
    then $(which firefox-nightly)
        if [ ! $? == 0 ]
        then echo "[Error] Firefox nightly (firefox-nightly) not found"; fi
    fi
fi

if [ "$1" == "work" ]
then _workramcopy; fi

if [ "$1" == "ram" ]
then _ramcopy; fi

if [ "$1" == "gold" ]
then export _golden=1
     _ramcopy; fi

if [ "$1" == "bad" ]
then _workramcopy bad; fi

if [ "$1" == "new" ]
then export _newram=1
    _ramcopy; fi

_createprofile
_startfirefox "${firefox_build}"
