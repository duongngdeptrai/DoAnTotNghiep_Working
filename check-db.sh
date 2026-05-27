#!/bin/bash
# Script to check device_permissions in MongoDB

echo "=== Checking device_permissions collection ==="
docker exec child-tracking-mongo mongosh --quiet --eval '
  print("Total device_permissions records:");
  print(db.device_permissions.countDocuments({}));
  print("\nAll device_permissions:");
  printjson(db.device_permissions.find({}).toArray());
  print("\nUsers in users collection:");
  printjson(db.users.find({}).project({passwordHash: 0}).toArray());
'