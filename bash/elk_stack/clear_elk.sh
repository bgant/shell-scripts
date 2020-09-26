#!/bin/bash

/etc/init.d/logstash stop
/etc/init.d/kibana stop
/etc/init.d/elasticsearch stop

rm /var/log/logstash/*
rm /var/log/kibana/*
rm /var/log/elasticsearch/*

rm -r /var/lib/elasticsearch/elasticsearch/nodes/0/indices/logstash-*

