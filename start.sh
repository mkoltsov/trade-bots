#!/bin/bash

git pull
bundle install
supervisorctl restart all