#!/bin/bash

sleep 10

while true;
do
    echo "hellllooo"

    echo "starting in /tmp"
    mkdir /tmp/testerrr

    echo "playing in .ssh"
    mkdir -p /.root/.ssh
    touch /.root/.ssh/tester

    sleep 10

    echo "hitting exec"
    touch /usr/bin/tester2

    sleep 10

    echo "hitting google"
    curl -s https://google.co.uk

    sleep 10

    echo "seeing history"
    cat /root/bash_history

    sleep 10

    echo "cleanup"
    rm -r /tmp/testerrr
    rm /usr/bin/tester2

done