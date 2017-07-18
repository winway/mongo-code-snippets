#! /bin/bash
#

PORT=1234
USER=read
PWD=read
DB=test
COL=foo

js=$(cat <<EOF
db.getMongo().setSlaveOk();
db = db.getMongo().getDB('admin');
db.auth('$USER', '$PWD');
db = db.getMongo().getDB('$DB');
cur = db.getCollection('$COL').find();
while (cur.hasNext()) {
    printjson(cur.next());
}
EOF
)

mongo --port $PORT --quiet --eval "$js"
