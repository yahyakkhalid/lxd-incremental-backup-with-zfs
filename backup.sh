#!/bin/bash

DIR=$1
ZFSPOOL=$2
DATE=$(date +'%m%d%Y')
HOUR=$(date +"%H")

# backup folders
[[ ! -d $DIR ]] && mkdir $DIR
[[ ! -d $DIR/$DATE ]] && mkdir $DIR/$DATE
[[ ! -d $DIR/$DATE/lxd ]] && mkdir $DIR/$DATE/lxd
[[ ! -d $DIR/$DATE/$ZFSPOOL ]] && mkdir $DIR/$DATE/$ZFSPOOL
[[ ! -d $DIR/logs ]] && mkdir $DIR/logs

LOGS_FILE=$DIR/logs/$DATE

echo "Checking if the $ZFSPOOL exists..." >> $LOGS_FILE
if [[ -z $(zpool list -Ho name | grep $ZFSPOOL) ]]; then
  echo "ERROR:	Storage pool $ZFSPOOL not found." >> $LOGS_FILE
  exit 1
fi

echo "Getting lxd version..." >> $LOGS_FILE
snap list lxd > $DIR/$DATE/lxd/lxd.version

echo "Saving lxd config..." >> $LOGS_FILE
lxd init --dump > $DIR/$DATE/lxd/lxd.config

echo "Fetching containers list..." >> $LOGS_FILE
ls /var/snap/lxd/common/lxd/storage-pools/$ZFSPOOL/containers > $DIR/$DATE/lxd/lxd.instances.list

echo "Backing up -" >> $LOGS_FILE

# Check if a full backup has already been done.
if [[ -z $(zfs list -t snapshot | grep backup) ]]; then
  echo "	full backup..." >> $LOGS_FILE
  zfs snapshot -r $ZFSPOOL@backup
  zfs send -R $ZFSPOOL@backup | xz > $DIR/$DATE/$ZFSPOOL/backup.img.xz
else
  # Check if a snapshot is already taken place.
  if [[ -z $(zfs list -t snapshot | grep snap) ]]; then
    past_snap="backup"
  else
    past_snap=$(zfs list -r -t snapshot -H -o name $ZFSPOOL | egrep -o "$ZFSPOOL@.+" | tail -n1)
  fi
  
  new_snap="$ZFSPOOL@snap-$DATE-$HOUR"
  
  # Check if the snapshot already exists.
  [[ $new_snap == $past_snap ]] && echo "INFO:	Backup has been already done." >> $LOGS_FILE && exit 1

  echo "	incremental backup..." >> $LOGS_FILE
  zfs snapshot -r $new_snap
  zfs send -RI $past_snap $new_snap | xz > $DIR/$DATE/$ZFSPOOL/snap-$HOUR.img.xz
fi
