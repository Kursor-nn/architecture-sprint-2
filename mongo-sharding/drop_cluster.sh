#!/bin/bash

echo "Drop stack"
docker-compose down
docker volume rm `docker volume ls | grep -i "mongo-sharding" | awk '{ print $2 }'`
echo "Down"