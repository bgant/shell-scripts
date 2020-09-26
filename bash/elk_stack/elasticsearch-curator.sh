#!/bin/bash

/usr/local/bin/curator --host 127.0.0.1 close indices --older-than 30 --time-unit days --timestring '%Y.%m.%d'
sleep 10
/usr/local/bin/curator --host 127.0.0.1 delete indices --older-than 90 --time-unit days --timestring '%Y.%m.%d'
sleep 10
/usr/local/bin/curator --host 127.0.0.1 optimize indices --older-than 4 --time-unit hours --timestring '%Y.%m.%d'

