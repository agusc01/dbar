#!/bin/sh

CLOCK=""

# Read local system time.
update_clock() {
    CLOCK=$(date '+%H:%M')
}
