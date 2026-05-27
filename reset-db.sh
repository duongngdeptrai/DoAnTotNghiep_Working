#!/bin/bash
# Script to reset all data in MongoDB for testing

echo "=== Resetting MongoDB data ==="
docker exec child-tracking-mongo mongosh --quiet --eval '
  db.getSiblingDB("child_tracking").users.drop();
  db.getSiblingDB("child_tracking").device_permissions.drop();
  db.getSiblingDB("child_tracking").locations.drop();
  print("Dropped all collections");
  print("Users count:", db.getSiblingDB("child_tracking").users.countDocuments({}));
  print("Device permissions count:", db.getSiblingDB("child_tracking").device_permissions.countDocuments({}));
  print("Locations count:", db.getSiblingDB("child_tracking").locations.countDocuments({}));
'
echo "=== Reset complete ==="