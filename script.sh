#!/bin/bash
#
# Reference
#
#  Cisco Catalyst 8000V Edge Software High Availability Configuration Guide - Configure High Availability on Cisco Catalyst 8000V Running on Amazon Web Services [Cisco IOS XE 17] - Cisco
#  https://www.cisco.com/c/en/us/td/docs/routers/C8000V/HighAvailability/c8000v-high-availability-configuration-guide/configure-high-availability-for-aws.html
#
#
# Command Options
#
#   arg1: Node Index (e.g. 1)
#   arg2: Region (e.g. us-west-2)
#   arg3: Route table Name (e.g. rtb-0123456789)
#   arg4: Next Hop Interface (e.g. eni-0123456789)
#   arg5: Route/CIDR Prefix (e.g. 0.0.0.0/0)
#   arg6: primary or secondary

create_node.py -i ${1} -rg ${2} -t ${3} -n ${4} -r ${5} -m ${6}
