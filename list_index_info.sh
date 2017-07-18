#! /bin/bash
#

PORT=1234
USER=read
PWD=read

js=$(cat <<EOF
db.getMongo().setSlaveOk();
db = db.getMongo().getDB('admin');
db.auth('$USER', '$PWD');
var dbs = db.adminCommand('listDatabases');
dbs.databases.forEach(function(e) {
    db = db.getMongo().getDB(e.name);
    var cols = db.getCollectionNames();
    cols.forEach(function(ee) {
        print('DB: ' + e.name + ', COL: ' + ee + ', INDEX: ' + tojsononeline(db.getCollection(ee).getIndexKeys()));
    })
})
EOF
)

mongo --port $PORT --quiet --eval "$js"
