#!/usr/bin/bash

BASE=/opt/projects/cpantesters
LOG=/opt/projects/cpantesters/uploads/logs/uploads2.log

cd $BASE/uploads
mkdir -p logs
mkdir -p data

date_format="%Y/%m/%d %H:%M:%S"
echo `date +"$date_format"` "START" >>$LOG

perl bin/uploads.pl --config=data/uploads.ini -b >>$LOG 2>&1

echo `date +"$date_format"` "Compressing Uploads data..." >>$LOG

cd $BASE/dbx
rm -f uploads.*
cp $BASE/uploads/data/uploads.db .  ; gzip  uploads.db
cp $BASE/uploads/data/uploads.db .  ; bzip2 uploads.db

mkdir -p /var/www/cpandevel/uploads
mv uploads.* /var/www/cpandevel/uploads

echo `date +"$date_format"` "STOP" >>$LOG
