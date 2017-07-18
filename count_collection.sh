#! /bin/bash
#

PORT=1234
USER=read
PWD=read
COL=foo

js=$(cat <<EOF
var cnt = 0;
db.getMongo().setSlaveOk();
db = db.getMongo().getDB('admin');
db.auth('$USER', '$PWD');
var dbs = db.adminCommand('listDatabases');
dbs.databases.forEach(function(e) {
    db = db.getMongo().getDB(e.name);
    var cols = db.getCollectionNames();
    cols.forEach(function(ee) {
        if (ee.indexOf('$COL') >= 0) {
            print('DB: ' + e.name + ', COL: ' + ee + ', COUNT: ' + db.getCollection(ee).count());
        }
        cnt += db.getCollection(ee).count();
    })
})
print("TOTAL COUNT: " + cnt);
EOF
)

mongo --port $PORT --quiet --eval "$js"
