#!/bin/sh

echo -e  "VMware virtual machine cloning. Ver1.0.0 (c)taiichi.nuki 2012-2015\n"

# Function definition
function info {
  echo -e "$(date '+%Y%m%d %T') Info: $@"
}

function error {
  echo -e "$(date '+%Y%m%d %T') Error: $@" 1>&2
}

function abort {
  echo -e "$(date '+%Y%m%d %T') Error: $@\n" 1>&2
  exit 1
}

# Initialization
datastoreBase=/vmfs/volumes
cmdName=$(basename $0)
srcVMName=$1
dstVMName=$2
dstDatastore=$3

vmDatabase=$(vim-cmd vmsvc/getallvms | awk 'NR>2 {printf "%s,%s,%s,%s", $2, $1, $3, $4}' | sort | sed -e s/[\]\[]//g)
vmRecord=$(echo "$vmDatabase" | grep "^$srcVMName,")

srcVMID=$(echo $vmRecord | awk '{print $2}')
srcDatastore=$(echo $vmRecord | awk '{print $3}')
srcDirectory=$(echo $vmRecord | awk '{print $4}')
srcPath="$datastoreBase/$srcDatastore/$srcDirectory"

dstDirectory="$dstVMName"
dstpath="$datastoreBase/$dstDatastore/$dstDirectory"

# Parameter number check
if [ $# -ne 3 ]; then
  echo -e "Usage: $cmdName <src-vmname> <dst-vmname> <dst-datastore>\n" 1>&2
  abort "Parameter number is not enough."
fi

# Source virtual machine existence check
if [ -z $vmRecord ]; then
  abort "Source virtual machine was not found in this ESXi."
fi

# Source virtual machine power state check
vim-cmd vmsvc/power.getstate $srcVMID | grep -q off 
if [ $? -ne 0 ]; then
  abort "Source virtual machine is not power off."
fi

# Destination virtual machine name duplicate check
if [ ! $(cat "$vmDatabase" | grep "^$dstVMName,") ]; then
  abort "Destination virtual machine name is duplicated."
fi

# Destination datastore existence check
if [ ! -d "$datastoreBase/$dstDatastore" ]; then
  abort "Destination datastore was not found in this ESXi."
fi

# Destination virtual machine directory existence check
if [ -d "$dstPath" ]; then
  abort "Destination virtual machine directory is already exist."
fi

# User confirmation 
echo '----- Source infomation ----------'
echo "VM ID:       $srcVMID"
echo "Name:        $srcVMName"
echo "Datastore:   $srcDatastore"
echo "Directory:   $srcDirectory"
echo '----- Destination infomation -----'
echo "Name:        $dstVMName"
echo "Datastore:   $dstDatastore"
echo "Directory:   $dstVMPath"
echo -e '----------------------------------\n'

read -p "Do you want to continue? (Y/[N]): " go
if [ $(echo $go | sed -e 's/y/Y/') != Y ]; then
  info "The operation has been canceled.\n"
  exit 0
fi

info "Process started."

# Source virtual machine unregistering 
info "Source virtual machine unregistering started."
vim-cmd vmsvc/unregister $srcVMID
if [ $? -ne 0 ]; then
  abort "Source virtual machine unregistering failed."
fi
info "Source virtual machine unregistering completed."

# File copy without .vmdk
mkdir -p "$dstPath"

find "$srcPath" -name 

for file in $(ls $vmPath | egrep -v ".*\.vmdk$|.*\.vmsn$|.*\.vswp|.*\.lck$|.*\.vmx~$"); do
        cp $vmPath/$file $backupPath/
        if [ $? -ne 0 ]; then
                echo "`date '+%y/%m/%d(%a) %T'` Error: File copy failed."
                echo "Error: File copy failed."
                echo "       Source file=$vmPath/$file"
                echo -e "       Dest   file=$backupPath/$file\n"
                exit 1
        fi
done


for file in `ls $oldPath/$vmName | grep -v .*\.vmdk$`; do
    cp $oldPath/$vmName/$file $newPath/$vmName/
    if [ $? -ne 0 ]; then
      echo "$(date '+%y/%m/%d %T')` Error: File copy failed."
      echo "Error: File copy failed." 1>&2
      echo "       Source file=$oldPath/$vmName/$file" 1>&2
      echo "       Dest   file=$newPath/$vmName/$file" 1>&2
      echo
      exit 1
    fi
  done
  # Clone vmdk file.
  for vmdkFile in `ls $oldPath/$vmName/*.vmdk | grep -v .*-flat\.vmdk$`; do
    vmdkFile=`basename $vmdkFile`
    vmkfstools -i $oldPath/$vmName/$vmdkFile -d thin $newPath/$vmName/$vmdkFile
    if [ $? -ne 0 ]; then
      echo "$(date '+%y/%m/%d %T')` Error: File copy failed."
      echo "Error: vmdk file clone failed." 1>&2
      echo "       cmdLine=vmkfstools -i $oldPath/$vmName/$vmdkFile -d thin $newPath/$vmName/$vmdkFile" 1>&2
      echo
      exit 1
    fi
  done
done
echo "$(date '+%y/%m/%d %T')` Info: File copy completed."
# Unregister VMs
echo "$(date '+%y/%m/%d %T')` Info: VM register started."
for vmName in `cat $vmList`; do
  vim-cmd solo/registervm $newPath/$vmName/$vmName.vmx
  if [ $? -ne 0 ]; then
    echo "$(date '+%y/%m/%d %T')` Error: VM register failed."
    echo "Error: vmName=$vmName register failed." 1>&2
    echo
    exit 1
  fi
done
echo "$(date '+%y/%m/%d %T')` Info: VM register completed."
# Delete file.
echo "$(date '+%y/%m/%d %T')` Info: File delete started."
while read vmName; do
  oldPath=/vmfs/volumes/$(echo "$vmdb" | grep "^$vmName,.*" | cut -d ',' -f 3)
  echo "$(date '+%y/%m/%d %T')` Info: Now processing vmName=$vmName."
  rm -fr $oldPath/$vmName
done < $vmList
echo "$(date '+%y/%m/%d %T') Info: File delete completed."
echo -e "$(date '+%y/%m/%d %T') Info: All prcess completed.\n"
exit 0