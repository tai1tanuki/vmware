#!/bin/sh

echo -e  "VMware virtual machine cloning tool. Ver1.0.0 (c)taiichi.nuki 2012-2016\n"

# Initialization
datastoreBase="/vmfs/volumes"
cmdName=$(basename $0)
srcVMName=$1
dstVMName=$2
dstDatastore=$3

vmDatabase=$(vim-cmd vmsvc/getallvms | awk 'NR>2 {printf "%s,%s,%s,%s\n", $2, $1, $3, $4}' | sort)
vmRecord=$(echo "$vmDatabase" | grep "^$srcVMName,")

srcVMID=$(echo $vmRecord | awk -F ',' '{print $2}')
srcVMXFile=$(echo $vmRecord | awk -F ',' '{print $4}')
dstVMXFile=$(echo $srcVMXFile | sed 's/$srcVMName/$dstVMName/')
srcDirectory=$(dirname "$srcVMXFile")
dstDirectory="$dstVMName"
srcDatastore=$(echo $vmRecord | awk -F ',' '{print $3}' | sed 's/[\]\[]//g')
dstPath="$datastoreBase/$dstDatastore/$dstDirectory"
srcPath="$datastoreBase/$srcDatastore/$srcDirectory"

# Parameter number check
if [ $# -ne 3 ]; then
  echo -e "Usage: $cmdName <src-vmname> <dst-vmname> <dst-datastore>\n" 1>&2
  echo -e "$(date '+%Y/%m/%d %T') Error: Parameter(s) is not enough or too many." 1>&2
  exit 1
fi

# Source virtual machine existence check
if [ -z $vmRecord ]; then
  echo -e "$(date '+%Y/%m/%d %T') Error: Source virtual machine was not found in this host."
  exit 1
fi

# Source virtual machine power state check
vim-cmd vmsvc/power.getstate $srcVMID | grep -q off 
if [ $? -ne 0 ]; then
  echo -e "$(date '+%Y/%m/%d %T') Error: Source virtual machine is not power off."
  exit 1
fi

# Destination virtual machine name duplicate check
if [ $(echo "$vmDatabase" | grep "^$dstVMName,") ]; then
  echo -e "$(date '+%Y/%m/%d %T') Error: Destination virtual machine name is duplicated."
  exit 1
fi

# Destination datastore existence check
if [ ! -d "$datastoreBase/$dstDatastore" ]; then
  echo -e "$(date '+%Y/%m/%d %T') Error: Destination datastore was not found in this host."
  exit 1
fi

# Destination virtual machine directory existence check
if [ -d "$dstPath" ]; then
  echo -e "$(date '+%Y/%m/%d %T') Error: Destination virtual machine directory is already exist."
  exit 1
fi

# User confirmation 
echo '----- Source infomation ----------'
echo "VM ID:       $srcVMID"
echo "Name:        $srcVMName"
echo "Datastore:   $srcDatastore"
echo "Directory:   $srcDirectory"
echo -e '\n----- Destination infomation -----'
echo "Name:        $dstVMName"
echo "Datastore:   $dstDatastore"
echo "Directory:   $dstVMPath"
echo -e '----------------------------------\n'

read -p "Do you want to continue? (Y/[N]): " go
if [ "$(echo $go | sed -e 's/y/Y/')" != 'Y' ]; then
  echo -e "$(date '+%Y/%m/%d %T') Info: Operation has been canceled.\n"
  exit 0
fi

echo -e "$(date '+%Y/%m/%d %T') Info: Process started."

# Virtual Machine file copy (w/o Virtual Disk)
echo -e "$(date '+%Y/%m/%d %T') Info: Virtual Machine file copy started."

mkdir -p "$dstPath"

for file in $(ls $srcPath | egrep -v ".*\.vmdk$|.*\.vmsn$|.*\.vswp|.*\.lck$|.*\.vmx~$"); do
  cp -p "$srcPath/$file" "$dstPath"
  if [ $? -ne 0 ]; then
    echo -e "$(date '+%Y/%m/%d %T') Error: Virtual Machine file copy failed. Source=$srcPath/$file Destination=$dstPath" 1>&2
    echo -e "$(date '+%Y/%m/%d %T') Error: Process aborted.\n" 1>&2
    exit 1
  fi      
done

echo -e "$(date '+%Y/%m/%d %T') Info: Virtual Machine file copy ended."

# Virtual Disk cloning
echo -e "$(date '+%Y/%m/%d %T') Info: Virtual Disk cloning started."

for file in $(ls $srcPath/*.vmdk | egrep -v ".*-flat\.vmdk$|.*-ctk\.vmdk"); do
  srcFile=$(basename $file)
  dstFile=$(echo $srcFile | sed 's/$srcVMName/$dstVMName/')
  cmd="vmkfstools -i $srcPath/$file -d thin $dstPath/$file"

  $cmd
  if [ $? -ne 0 ]; then
    echo -e "$(date '+%Y/%m/%d %T') Error: Virtual Disk cloning failed. Source=$srcPath/$file Destination=$dstPath/$file CommandLine=$cmd" 1>&2
    echo -e "$(date '+%Y/%m/%d %T') Error: Process aborted.\n" 1>&2
    exit 1
  fi      
done

echo -e "$(date '+%Y/%m/%d %T') Info: Virtual Disk cloning ended."

# Cloned Virtual Machine registering
echo -e "$(date '+%Y/%m/%d %T') Info: Cloned Virtual Machine registering started."
vim-cmd solo/registervm "$dstPath/$dstVMName.vmx"
if [ $? -ne 0 ]; then
  echo -e "$(date '+%Y/%m/%d %T') Error: Cloned Virtual Machine registering failed." 1>&2
  echo -e "$(date '+%Y/%m/%d %T') Error: Process aborted.\n" 1>&2
  exit 1
fi
echo -e "$(date '+%Y/%m/%d %T') Info: Cloned Virtual Machine registering ended."

echo -e "$(date '+%Y/%m/%d %T') Info: All process has been completed." 

exit 0