#!/bin/bash

homeDir=$(pwd)"/"

bash $homeDir/get_old_schema.sh
bash $homeDir/get_new_schema.sh
bash $homeDir/compare_schema.sh