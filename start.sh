#!/bin/bash

pkill -f 'ruby'

git pull

nohup ruby ./main.rb --start worker-1 &

nohup ruby ./main.rb --listen worker-2 &