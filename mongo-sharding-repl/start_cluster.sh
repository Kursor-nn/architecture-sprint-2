#!/bin/bash

echo "Hello, World!"

configSrvRS="config-server-rs"
configSrv="configSrv"

shard1Rs="shard1-rs"
shard1="shard1_1"
shard1_2="shard1_2"
shard1_3="shard1_3"

shard2Rs="shard2-rs"
shard2="shard2_1"
shard2_2="shard2_2"
shard2_3="shard2_3"

dbname="somedb"
docname="helloDoc"

defaultPort=27017

echo "===Run cluster=============================================="
docker-compose up -d

echo "===Init config Server======================================="
docker-compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate(
  {
    _id: "config-server-rs",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" },
    ]
  }
)
EOF
echo "============================================================"

echo "===Wait 10s================================================="
sleep 10

echo "===Init shard 1 ============================================"
docker compose exec -T shard1_1 mongosh --port 27017 <<EOF
rs.initiate(
    {
      _id : "shard1-rs",
      members: [
        { _id : 0, host : "shard1_1:27017" },
        { _id : 1, host : "shard1_2:27017" },
        { _id : 2, host : "shard1_3:27017" },
      ]
    }
);
EOF

echo "===Init shard 2 ============================================"
docker compose exec -T shard2_1 mongosh --port 27017 <<EOF
rs.initiate(
    {
      _id : "shard2-rs",
      members: [
        { _id : 0, host : "shard2_1:27017" },
        { _id : 1, host : "shard2_2:27017" },
        { _id : 2, host : "shard2_3:27017" },
      ]
    }
);
EOF

echo "===Init router ============================================"

docker-compose exec -T router mongosh --port 27017 <<EOF
sh.addShard( "shard1-rs/shard1_1:27017");
sh.addShard( "shard2-rs/shard2_1:27017");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
EOF

echo "===Configuration is done==================================="

echo "===Fill data==============================================="

docker-compose exec -T router mongosh <<EOF
use ${dbname}
for(var i = 0; i < 1000; i++) db.${docname}.insertOne({age:i, name:"ly"+i})
EOF

echo "===Check count of data via router=========================="

docker compose exec -T router mongosh --port ${defaultPort} <<EOF
use ${dbname};
db.${docname}.countDocuments();
EOF

echo "===Check count of data via shard1========================="

docker compose exec -T ${shard1} mongosh --port ${defaultPort} <<EOF
use ${dbname};
db.${docname}.countDocuments();
EOF

docker compose exec -T ${shard1_2} mongosh --port ${defaultPort} <<EOF
use ${dbname};
db.${docname}.countDocuments();
EOF

docker compose exec -T ${shard1_3} mongosh --port ${defaultPort} <<EOF
use ${dbname};
db.${docname}.countDocuments();
EOF

echo "===Check count of data via shard2========================="

docker compose exec -T ${shard2} mongosh --port ${defaultPort} <<EOF
use ${dbname};
db.${docname}.countDocuments();
EOF

docker compose exec -T ${shard2_2} mongosh --port ${defaultPort} <<EOF
use ${dbname};
db.${docname}.countDocuments();
EOF

docker compose exec -T ${shard2_3} mongosh --port ${defaultPort} <<EOF
use ${dbname};
db.${docname}.countDocuments();
EOF

echo "===Check via rest api==================================="
RESPONSE=$(curl http://localhost:8080/$docname/count)
countOfDocuments=`echo $RESPONSE | awk -F"," '{ print $3 }'  | awk -F":" '{ print substr($2, 1, length($2)-1) }'`

if [[ $countOfDocuments != 0 ]]; then
  echo "======================================================"
  echo "Success. Current number of documents: ${countOfDocuments} != 0";
else
  echo "Failed. Current number of documents: ${countOfDocuments}";
fi
echo "======================================================"