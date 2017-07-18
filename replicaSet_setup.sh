#! /bin/bash
#

ROOTPWD=123456

usage () {
    echo "##############################################"
    echo "$(basename $0) -f <configuration file>"
    echo "-f configuration file"
    echo "##############################################"
    exit 1
}

conf=
while getopts "f:" opt
do
    case $opt in
    f)
      conf="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      usage
      ;;
  esac
done

shift $(($OPTIND - 1))

if [[ -z "$conf" ]]
then
    usage
fi

# create global variables: REPLICATION, PORT
eval $(sed 's/[ \t][ \t]*//g; /^#/d' $conf | \
awk '
/\[global\]/ {
    start = 1;
    next;
}
/^[ \t]*$/ && start == 1{
    start = 0;
    next;
}
start == 1 {
    print;
}')

# spawn js command for create user
js_createuser=$(sed 's/[ \t][ \t]*//g; /^#/d' $conf | \
awk '
BEGIN {
    n = 0;
}
/\[privilege\]/ {
    start = 1;
    next;
}
/^[ \t]*$/ && start == 1{
    start = 0;
    print "db = db.getMongo().getDB('\''admin'\'');";
    if (n == 0) {
        print "db.createUser({'\''user'\'' : '\''root'\'', '\''pwd'\'': '\'"$ROOTPWD"\'', '\''roles'\'' : [ { role: '\''root'\'', db: '\''admin'\'' }]});"
        print "sleep(2000);"
        print "db.auth('\''root'\'', '\'"$ROOTPWD"\'');";
    }

    print "sleep(2000);"

    if (vars["READONLY"] == "false") {
        print "db.createUser( { '\''user'\'' : '\''" vars["USER"] "'\'', '\''pwd'\'': '\''" vars["PASSWORD"] "'\'', '\''roles'\'' : [ { role: '\''readWriteAnyDatabase'\'', db: '\''admin'\'' }, { role: '\''dbAdminAnyDatabase'\'', db: '\''admin'\'' }, { role: '\''clusterMonitor'\'', db: '\''admin'\'' } ]});"
    }
    else if (vars["READONLY"] == "true") {
        print "db.createUser( { '\''user'\'' : '\''" vars["USER"] "'\'', '\''pwd'\'': '\''" vars["PASSWORD"] "'\'', '\''roles'\'' : [ { role: '\''readAnyDatabase'\'', db: '\''admin'\'' }, { role: '\''clusterMonitor'\'', db: '\''admin'\'' } ]});"
    }
    delete vars;
    n += 1;
    next;
}
start == 1 {
    split($0, a, "=");
    vars[a[1]] = a[2];
}')

# spawn rs conf
js_rsconf=$(sed 's/[ \t][ \t]*//g; /^#/d' $conf | \
awk '
BEGIN {
    n = 0;
}
/\[node\]/ {
    start = 1;
    next;
}
/^[ \t]*$/ && start == 1{
    start = 0;
    print "        {";
    print "            '\''_id'\'' : " n ",";
    if (vars["PORT"]) {
        port = vars["PORT"];
    } else {
        port = '$PORT';
    }
    print "            '\''host'\'' : '\''" vars["HOST"] ":" port "'\'',";
    if (vars["PRIORITY"]) {
        print "            '\''priority'\'' : " vars["PRIORITY"] ",";
    }
    if (vars["ARBITER"]) {
        print "            '\''arbiterOnly'\'' : true,";
    }
    if (vars["HIDDEN"]) {
        print "            '\''priority'\'' : 0,";
        print "            '\''hidden'\'' : true,";
    }
    print "        },";
    delete vars;
    n += 1;
    next;
}
start == 1 {
    split($0, a, "=");
    vars[a[1]] = a[2];
}')

jscript=$(cat <<EOF
var err = rs.initiate();
printjson(err);
while (rs.status().startupStatus || (rs.status().hasOwnProperty("myState") && rs.status().myState != 1)) {
    printjson( rs.status() );
    sleep(3000);
};
printjson( rs.status() );
$js_createuser
conf = {
    "_id" : "$REPLICATION",
    "version" : 1,
    "protocolVersion" : NumberLong(1),
    "members" : [
$js_rsconf
    ]
};
printjson(conf);
var err = rs.reconfig(conf);
printjson(err);
for (var i=0; i<5; i++) {
    sleep(5000);
    printjson( rs.status() );
};
EOF)

echo "$jscript"

mongo --port $PORT --eval "$jscript"

echo "try mongo --port $PORT"
