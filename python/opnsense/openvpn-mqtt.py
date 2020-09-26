#!/usr/local/bin/python3
#
# Source: https://iotbytes.wordpress.com/paho-mqtt-with-python/
#

# Import package
import paho.mqtt.client as mqtt
import subprocess
import time

# Define Variables
MQTT_CLIENT_ID = "opnsense"
MQTT_HOST = "192.168.7.103"
MQTT_PORT = 1883
MQTT_KEEPALIVE_INTERVAL = 45
MQTT_TOPIC_PUB = "devices/" + MQTT_CLIENT_ID + "/openvpn/status"

# Initialize variables
MQTT_MSG_PUB = ""
MQTT_MSG_SUB = ""
timeout = 0

# Define on_publish event function
def on_publish(client, userdata, mid):
    print("PUB: ", MQTT_TOPIC_PUB , MQTT_MSG_PUB)

# Define on_message even function
# (treat like interrupt call)
def on_message(client, userdata, message):
    global MQTT_MSG_SUB
    MQTT_MSG_SUB = str(message.payload.decode("UTF-8")) 
    print("SUB: ", MQTT_TOPIC_SUB, MQTT_MSG_SUB)

# Initiate MQTT Client
mqttc = mqtt.Client(MQTT_CLIENT_ID)

# Register callback functions
mqttc.on_publish = on_publish
mqttc.on_message = on_message

# Connect with MQTT Broker
mqttc.connect(MQTT_HOST, MQTT_PORT, MQTT_KEEPALIVE_INTERVAL) 

# Subscribe to MQTT topic
MQTT_TOPIC_SUB = "devices/" + MQTT_CLIENT_ID + "/openvpn/control"
mqttc.subscribe(MQTT_TOPIC_SUB)
mqttc.loop_start()  # Subscribe listening loop/interrupt

# Publish message to MQTT Broker 
try:
    while True:
        if MQTT_MSG_SUB == MQTT_MSG_PUB:
            # Nothing to do
            pass
        elif MQTT_MSG_SUB == "off":
            subprocess.getoutput('/usr/local/sbin/configctl openvpn stop')
            while subprocess.getoutput('/usr/local/sbin/configctl openvpn status') == "on" and timeout < 20:
                print("      Waiting for OpenVPN service to stop...")
                time.sleep(2)
                timeout += 2
            MQTT_MSG_SUB = ""  # Clear control variable
        elif MQTT_MSG_SUB == "on":
            subprocess.getoutput('/usr/local/sbin/configctl openvpn start')
            while subprocess.getoutput('/usr/local/sbin/configctl openvpn status') == "off" and timeout < 20:
                print("      Waiting for OpenVPN service to start...")
                time.sleep(4)
                timeout += 4
            MQTT_MSG_SUB = ""  # Clear control variable
        else:
            # Ignore values that are not "on" or "off"
            pass

        MQTT_MSG_PUB = subprocess.getoutput('/usr/local/sbin/configctl openvpn status')
        mqttc.publish(MQTT_TOPIC_PUB,MQTT_MSG_PUB)
        time.sleep(3)

# Disconnect from MQTT_Broker
except:
    mqttc.disconnect()

