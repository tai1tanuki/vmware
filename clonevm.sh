#!/bin/sh

echo -e  "VMware virtual machine cloning tool. Ver1.0.0 (c)taiichi.nuki 2012-2016\n"

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
datastoreBase="/vmfs/volumes"
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

# Virtual Machine file copy (w/o Virtual Disk)
info "Virtual Machine file copy started."

mkdir -p "$dstPath"

for file in $(ls $srcPath | egrep -v ".*\.vmdk$|.*\.vmsn$|.*\.vswp|.*\.lck$|.*\.vmx~$"); do
  cp -p "$srcPath/$file" "$dstPath/"
  if [ $? -ne 0 ]; then
    error "Virtual Machine file copy failed. Source=$srcPath/$file Destination=$dstPath"
    abort "Process aborted."
  fi      
done

info "Virtual Machine file copy ended."

# Virtual Disk cloning
info "Virtual Disk cloning started."

for file in $(ls $srcPath/*.vmdk | egrep -v ".*-flat\.vmdk$"); do
  file=$(basename $file)
  $cmd="vmkfstools -i $srcPath/$file -d thin $dstPath/$file"

  $cmd
  if [ $? -ne 0 ]; then
    error "Virtual Disk cloning failed. Source=$srcPath/$file Destination=$dstPath/$file CommandLine=$cmd"
    abort "Process aborted."
  fi      
done

info "Virtual Disk cloning ended."

# Register VMs
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