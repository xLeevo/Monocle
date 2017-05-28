#!/bin/bash
slc ctl -C "http://${SVUSER}:${SVPASS}@mover1:8701/" restart pgomap-api-services
