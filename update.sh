#!/bin/bash
set -x
set -e
./deploy_software.pl --create packages/*
mv repository.json merged-json/
git commit -m "updated repository"
git push
