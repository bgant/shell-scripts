#!/bin/bash

/etc/init.d/logstash stop
sleep 30
rm /var/log/logstash/*
/etc/init.d/logstash start

