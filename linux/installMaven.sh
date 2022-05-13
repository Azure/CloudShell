#!/bin/bash

# Customized Maven install from Apache mirrors according to best practices

# Download maven from Apache Mirror
MAVEN_VERSION=3.8.5
wget https://dlcdn.apache.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz -P /opt
tar xf /opt/apache-maven-$MAVEN_VERSION-bin.tar.gz -C /opt
ln -s /opt/apache-maven-$MAVEN_VERSION /opt/maven
