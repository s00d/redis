#!/bin/bash

# CREATED:
# vitaliy.natarov@yahoo.com
#
# Unix/Linux blog:
# http://linux-notes.org
# Vitaliy Natarov
#
# Set some colors for status OK, FAIL and titles
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"

SETCOLOR_TITLE="echo -en \\033[1;36m" #Fuscia
SETCOLOR_NUMBERS="echo -en \\033[0;34m" #BLUE
function Operation_status {
     if [ $? -eq 0 ]; then
         $SETCOLOR_SUCCESS;
         echo -n "$(tput hpa $(tput cols))$(tput cub 6)[OK]"
         $SETCOLOR_NORMAL;
             echo;
     else
        $SETCOLOR_FAILURE;
        echo -n "$(tput hpa $(tput cols))$(tput cub 6)[fail]"
        $SETCOLOR_NORMAL;
        echo;
     fi
}

# LOGS
FlushCacheReport="/var/log/FlushCacheReport.log"
if [ ! -f "$FlushCacheReport" ]; then
    $SETCOLOR_TITLE
    echo "The file flushall-caches.log NOT FOUND in the folder /var/log";
    $SETCOLOR_NORMAL
    touch $FlushCacheReport
    $SETCOLOR_TITLE
    echo "The file $FlushCacheReport was CREATED";
    $SETCOLOR_NORMAL
else
    $SETCOLOR_TITLE
    echo "The file '$FlushCacheReport' Exists"
    rm -f $FlushCacheReport
    touch $FlushCacheReport
    $SETCOLOR_NORMAL
fi

# Receiver email for Unknown_malewares.log and reports
 List_of_emails="vitaliy.natarov@yahoo.com"

exec > >(tee -a ${FlushCacheReport} )
exec 2> >(tee -a ${FlushCacheReport} >&2)

echo "**************************************************************" >> $FlushCacheReport
echo "HOSTNAME: `hostname`" >> $FlushCacheReport
echo "**************************************************************" >> $FlushCacheReport

if ! type -path "expect" > /dev/null 2>&1; then
             yum install expect -y
             $SETCOLOR_TITLE
             echo "expect was INSTALLED on this server: `hostname`";
             $SETCOLOR_NORMAL
else
        $SETCOLOR_TITLE
        echo "expect INSTALLED on this server: `hostname`";
        $SETCOLOR_NORMAL
fi

RootF=$(cat /etc/nginx/conf.d/*.conf | grep root|cut -d ";" -f1 | awk '{print $2}'|grep -vE "(SCRIPT_FILENAME|fastcgi_param|fastcgi_script_name|-f)"|uniq)

for Roots in `echo $RootF|xargs -I{} -n1 echo {}` ; do
    $SETCOLOR_TITLE
    echo "Root-folder: `echo $Roots`";
    $SETCOLOR_NORMAL

    LocalXML="$Roots/app/etc/local.xml"
    $SETCOLOR_TITLE
    echo "Root-XML: `echo $LocalXML`";
    $SETCOLOR_NORMAL

    # SERVER_IP
    # check redis IP
    CacheRedisIP=$(cat $Roots/app/etc/local.xml| grep Cache_Backend_Redis -A13 | grep "<server>"|uniq| cut -d ">" -f2 | cut -d "<" -f1)
    #CacheRedisIP=$(cat $Roots/app/etc/local.xml| grep Cache_Backend_Redis -A13 | grep "<server>"| cut -d ">" -f2 | cut -d "<" -f1)
    echo "Cache Redis server/IP: `echo $CacheRedisIP`";
    #

    #PORTS
    CacheRedisPorts=$(cat $Roots/app/etc/local.xml| grep Cache_Backend_Redis -A13 | grep port | cut -d ">" -f2 |cut -d "<" -f1)
    echo "Cache-redis-ports: `echo $CacheRedisPorts`";

    # PS 6381 - don't to flush
    IgnoreCacheRedisPorts="6381"
    #
    # redis-cli -h 127.0.0.1 -p 6378 flushall   (sessions)
    # redis-cli -h 127.0.0.1 -p 6379 flushall   (cache)
    # redis-cli -h 127.0.0.1 -p 6380 flushall    (full_page_cache)

     #Check_DB
    CacheRedisDB=$(cat $Roots/app/etc/local.xml| grep Cache_Backend_Redis -A13 | grep database | cut -d ">" -f2 |cut -d "<" -f1)
    echo "CacheRedisDB = `echo $CacheRedisDB`"
    #
    for ICacheRedisIP in `echo $CacheRedisIP|xargs -I{} -n1 echo {}` ; do
            echo "Cache Redis server: `echo $ICacheRedisIP`";
            for ICacheRedisPorts in `echo $CacheRedisPorts|xargs -I{} -n1 echo {}` ; do
                if [ "$ICacheRedisPorts" -ne "$IgnoreCacheRedisPorts" ]; then
                         if [ -z "$CacheRedisDB" ]; then
                             R_flush=$(redis-cli -h `echo $ICacheRedisIP` -p `echo $ICacheRedisPorts` flushall)
                             $SETCOLOR_TITLE
                             echo "redis-cli -h `echo $ICacheRedisIP` -p `echo $ICacheRedisPorts` flushall";
                             $SETCOLOR_NORMAL
                          else
                                #flush_db
                                for ICacheRedisDB in `echo $CacheRedisDB|xargs -I{} -n1 echo {}|uniq` ; do
                                    echo "Need to flush DB `echo $ICacheRedisDB`";
                                    #
                                    Flush_CacheRedisDB="flushdb";
                                    Close_Expect_with_CacheRedis="quit";
                                    #
                                    `which expect | grep -E expect`<<EOF
                                    spawn telnet $ICacheRedisIP $ICacheRedisPorts
                                    expect "Escape character is '^]'."
                                    send "SELECT $ICacheRedisDB\n"
                                    expect "+OK"
                                    send "$Flush_CacheRedisDB\n"
                                    expect "+OK"
                                    sleep 1
                                    send "$Close_Expect_with_CacheRedis\n"
EOF
                                done;     
                          fi         
                else
                     echo "Ops IgnoreCacheRedisPorts is '$IgnoreCacheRedisPorts' EXIT!";
                     #exit;
                     break;
                fi
                echo "Flushed redis cache on $ICacheRedisPorts port";
            done;
     done;
done;

#MEMCACHED
MemcachedServer=$(cat $RootF/app/etc/local.xml| grep '<memcached>' -A7| grep -E 'host|CDATA|port' | grep -v "ersistent"| grep host| cut -d "[" -f3| cut -d "]" -f1|uniq)
MemcachedPort=$(cat $RootF/app/etc/local.xml| grep '<memcached>' -A7| grep -E 'host|CDATA|port' | grep -v "ersistent"| grep port| cut -d "[" -f3| cut -d "]" -f1|uniq)

Close_Expect_with_Memcached="quit"
Flush_Memcached="flush_all"

if [ -z "$MemcachedServer|$MemcachedPort" ]; then
    `which expect | grep -E expect`<<EOF
     spawn telnet $MemcachedServer $MemcachedPort
     expect "Escape character is '^]'."
     send "$Flush_Memcached\n"
     expect "+OK"
     sleep 1
     send "$Close_Expect_with_Memcached\n"
EOF
    echo "memcached has been flushed on server `hostname`";
else
     $SETCOLOR_TITLE
     echo "Din't find memcached on server `hostname`";
     $SETCOLOR_NORMAL
fi

# Send report to email list
#
mail -s " HOSTNAME is `hostname`" $List_of_emails < $FlushCacheReport
echo "LOG_FILE= $FlushCacheReport has been sent";
#
echo "|---------------------------------------------------|";
echo "|--------------------FINISHED-----------------------|";
echo "|---------------------------------------------------|";