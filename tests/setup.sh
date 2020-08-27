#!/bin/bash

# configures the environment for running the unit tests

# Set up environment for testing
adduser --disabled-login --gecos "" --uid 9527 csuser

# allow all users to write to /tests directory 
chmod -R 0777 /tests