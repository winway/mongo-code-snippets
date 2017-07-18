#! /bin/bash
#

PORT=1234
DB=test
COL=foo

js=$(cat <<EOF
db.getMongo().setSlaveOk();
db = db.getMongo().getDB('admin');
db.auth('read', 'read');
db = db.getMongo().getDB('$DB');
cur = db.getCollection('$COL').find();
while (cur.hasNext()) {
    printjson(cur.next());
}
EOF
)

mongo --port $PORT --eval "$js"
