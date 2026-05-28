#!/bin/bash

if [ ! -e "/data/WiredTiger" ] && [ ! -e "/data/journal" ] && [ ! -e "/data/local.0" ] && [ ! -e "/data/storage.bson" ]; then
    mongod --replSet rs0 --dbpath /data --logpath /logs --pidfilepath /data/mongod.pid --fork
    mongosh admin -eval "rs.initiate({ _id: 'rs0', members: [ {_id: 0, host: 'mdb0:27017' } ] })"

    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
          *.sh) echo "$0: running $f"; . "$f" ;;
          *.js)
            echo "$0: running $f";
            fileName=$(basename $f)
            dbName=${fileName%%.js}
            "mongosh" "$dbName" "$f"; echo ;;
          *)    echo "$0: ignoring $f" ;;
        esac
        echo
    done

    mongod --replSet rs0 --dbpath /data --logpath /logs --pidfilepath /data/mongod.pid --shutdown

    echo
    echo 'MongoDB init process complete; ready for start up.'
    echo
fi
mongod "--config" /etc/mongo/mongod.conf