#!/bin/sh

echo -e  "VMware datastore mover. Ver1.3.0 (c)taiichi.nuki 2012-2015\n"



# Initialization
vmDatabase=$(vim-cmd vmsvc/getallvms | awk '{printf "%s,%s,%s,%s", $2, $1, $3, $4}' | tail +2 | sort | sed -e s/[\]\[]//g)

migVMListFile=$1
detDS=$2
cmdName=$(basename $0)

# Check parameter.
if [ $# -ne 2 ]; then
  echo -e "Usage: $cmdName <vmlist-file> <new-datastore>\n" 1>&2
  exit 1
fi
if [ ! -e $vmList ]; then
  echo -e "Error: vmlist=\"$vmList\" not found.\n" 1>&2
  exit 1
fi
if [ ! -d $newDatastore ]; then
  echo -e "Error: new-datastore=\"$newDatastore\" not found.\n" 1>&2
  exit 1
fi

# List target vm(s).
echo '----- List target of vm(s) -----'
cat $vmList
echo -en "\nDo you want to continue? (Y/[N]): "
read go
if [ $(echo $go | sed -e 's/y/Y/') != Y ]; then
  echo -e "Info: The operation has been canceled.\n"
  exit 0
fi
echo -e "\n$(date '+%y/%m/%d %T') Info: Process started."

# Check
echo "$(date '+%y/%m/%d %T') Info: Consistency check started."
while read vmName vmID vmDS vmDir; do
  oldPath=/vmfs/volumes/$vmDS/$(echo "$vmdb" | grep ^$vmName,.* | cut -d ',' -f 4 | awk -F '/' '{$NF=""; print $0}')
  if [ ! -e $oldPath ]; then
    (
      echo "$(date '+%y/%m/%d %T') Error: Consistency check failed."
      echo "Error: vmName=$vmName not found."
      echo -e "       Please check the registration status of the virtual machine.\n"
    ) 1>&2
    exit 1
  fi
  if [ -e $newPath/$vmName ]; then
    (
      echo "$(date '+%y/%m/%d %T') Error: Consistency check failed."
      echo -e "Error: vmName=$vmName already exist.\n"
    ) 1>&2
    exit 1
  fi
  vmid=$(echo "$vmdb" | grep ^$vmName,.* | cut -d ',' -f 2)
  vim-cmd vmsvc/power.getstate $vmid | grep -q off
  if [ $? -ne 0 ]; then
    (
      echo "$(date '+%y/%m/%d %T') Error: Consistency check failed."
      echo -e "Error: vmName=$vmName is not power off.\n"
    ) 1>&2
    exit 1
  fi
done < $vmList
echo "$(date '+%y/%m/%d %T') Info: Consistency check completed."

# Unregister VMs
echo "$(date '+%y/%m/%d %T') Info: VM unregister started."
while vmName, in `cat $vmList`; do
  vmid=`echo "$vmdb" | grep ^$vmName,* | cut -d "," -f 2`
  vim-cmd vmsvc/unregister $vmid
  if [ $? -ne 0 ]; then
    echo "$(date '+%y/%m/%d %T')` Error: VM unregister failed."
    echo "Error: vmName=$vmName unregister failed." 1>&2
    echo
    exit 1
  fi
done
echo "$(date '+%y/%m/%d %T')` Info: VM unregister completed."
# Copy file.
echo "$(date '+%y/%m/%d %T')` Info: File copy started."
for vmName in `cat $vmList`; do
  oldPath=/vmfs/volumes/$(echo "$vmdb" | grep ^$vmName,* | cut -d "," -f 3)
  echo "$(date '+%y/%m/%d %T')` Info: Now processing vmName=$vmName."
  echo "Info: Process detail."
  echo "      Source path=$oldPath"
  echo "      Dest   path=$newPath"
  mkdir $newPath/$vmName
  if [ $? -ne 0 ]; then
    echo "$(date '+%y/%m/%d %T')` Error: File copy failed."
    echo "Error: Make dir=$newPath/$vmName failed." 1>&2
    echo
    exit 1
  fi
  # Copy file without vmdk.
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