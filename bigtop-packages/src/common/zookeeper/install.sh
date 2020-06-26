#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -ex

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to dist.dir
     --source-dir=DIR            path to package shared files dir
     --prefix=PREFIX             path to install into

  Optional options:
     --lib-dir=DIR               path to install Zookeeper home [/opt/[stack_name]/[stack_version]/zookeeper/lib]
     --stack-home=DIR            path to install dirs [/opt/[stack_name]/[stack_version]/zookeeper]
     --component-name=NAME       component-name
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'lib-dir:' \
  -l 'source-dir:' \
  -l 'stack-home:' \
  -l 'component-name:' \
  -l 'build-dir:' -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --source-dir)
        SOURCE_DIR=$2 ; shift 2
        ;;
        --lib-dir)
        LIB_DIR=$2 ; shift 2
        ;;
        --stack-home)
        STACK_HOME=$2 ; shift 2
        ;;
        --component-name)
        COMPONENT_NAME=$2 ; shift 2
        ;;
        --)
        shift ; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

for var in PREFIX BUILD_DIR SOURCE_DIR; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

if [ -f "$SOURCE_DIR/bigtop.bom" ]; then
  . $SOURCE_DIR/bigtop.bom
fi


LIB_DIR=${LIB_DIR:-$STACK_HOME/$COMPONENT_NAME}
install -d -m 0755 $PREFIX/$LIB_DIR/

cp -a $BUILD_DIR/zookeeper-*.jar $PREFIX/$LIB_DIR
ln -s $STACK_HOME/$COMPONENT_NAME/zookeeper-$ZOOKEEPER_VERSION.jar $PREFIX/$STACK_HOME/$COMPONENT_NAME/zookeeper.jar

CONF_DIR=${CONF_DIR:-$STACK_HOME/etc/$COMPONENT_NAME/conf.dist}
install -d -m 0755 $PREFIX/$CONF_DIR
cp -a $BUILD_DIR/conf/* $PREFIX/$CONF_DIR
cp -a $SOURCE_DIR/zoo.cfg $PREFIX/$CONF_DIR
cp -a $SOURCE_DIR/zookeeper-env.sh $PREFIX/$CONF_DIR


install -d -m 0755 $PREFIX/$STACK_HOME/$COMPONENT_NAME/bin
install -d -m 0755 $PREFIX/$STACK_HOME/$COMPONENT_NAME/doc
install -d -m 0755 $PREFIX/$STACK_HOME/$COMPONENT_NAME/lib
cp -a $BUILD_DIR/bin/* $PREFIX/$STACK_HOME/$COMPONENT_NAME/bin/
rm -fr $PREFIX/$STACK_HOME/$COMPONENT_NAME/bin/*.txt
rm -fr $PREFIX/$STACK_HOME/$COMPONENT_NAME/bin/*.cmd
cp -a $BUILD_DIR/lib/* $PREFIX/$STACK_HOME/$COMPONENT_NAME/lib/
cp -a $BUILD_DIR/docs/* $PREFIX/$STACK_HOME/$COMPONENT_NAME/doc/


echo '#!/bin/bash' > $PREFIX/$STACK_HOME/$COMPONENT_NAME/bin/zkServer-initialize.sh

chmod 755 $PREFIX/$STACK_HOME/$COMPONENT_NAME/bin/zkServer-initialize.sh


MAN_DIR=${MAN_DIR:-$STACK_HOME/$COMPONENT_NAME/man/man1}
install -d -m 0755 $PREFIX/$MAN_DIR
gzip -c $SOURCE_DIR/zookeeper.1 > $PREFIX/$MAN_DIR/zookeeper.1.gz


ln -s /var/log/$COMPONENT_NAME $PREFIX/$STACK_HOME/$COMPONENT_NAME/logs
ln -s /var/run/$COMPONENT_NAME $PREFIX/$STACK_HOME/$COMPONENT_NAME/run
ln -s /etc/$COMPONENT_NAME/conf $PREFIX/$STACK_HOME/$COMPONENT_NAME/conf

wrapper=$PREFIX/$STACK_HOME/$COMPONENT_NAME/bin/zookeeper-client
install -d -m 0755 `dirname $wrapper`
cat > $wrapper <<EOF
#!/bin/bash

export ZOOKEEPER_HOME=$STACK_HOME/$COMPONENT_NAME
export ZOOKEEPER_CONF=$STACK_HOME/$COMPONENT_NAME/conf
export CLASSPATH=\$CLASSPATH:\$ZOOKEEPER_CONF:\$ZOOKEEPER_HOME/*:\$ZOOKEEPER_HOME/lib/*
export ZOOCFGDIR=\${ZOOCFGDIR:-\$ZOOKEEPER_CONF}
env CLASSPATH=\$CLASSPATH $STACK_HOME/$COMPONENT_NAME/bin/zkCli.sh "\$@"
EOF
chmod 755 $wrapper



for pairs in zkServer.sh/zookeeper-server zkServer-initialize.sh/zookeeper-server-initialize zkCleanup.sh/zookeeper-server-cleanup ; do
  wrapper=$PREFIX/$STACK_HOME/$COMPONENT_NAME/bin/`basename $pairs`
  upstream_script=`dirname $pairs`
  cat > $wrapper <<EOF
#!/bin/bash

export ZOOPIDFILE=\${ZOOPIDFILE:-/var/run/zookeeper/zookeeper_server.pid}
export ZOOKEEPER_HOME=\${ZOOKEEPER_CONF:-$STACK_HOME/$COMPONENT_NAME}
export ZOOKEEPER_CONF=\${ZOOKEEPER_CONF:-$STACK_HOME/$COMPONENT_NAME/conf}
export ZOOCFGDIR=\${ZOOCFGDIR:-\$ZOOKEEPER_CONF}
export CLASSPATH=\$CLASSPATH:\$ZOOKEEPER_CONF:\$ZOOKEEPER_HOME/*:\$ZOOKEEPER_HOME/lib/*
export ZOO_LOG_DIR=\${ZOO_LOG_DIR:-/var/log/zookeeper}
export ZOO_LOG4J_PROP=\${ZOO_LOG4J_PROP:-INFO,ROLLINGFILE}
export JVMFLAGS=\${JVMFLAGS:--Dzookeeper.log.threshold=INFO}
export ZOO_DATADIR_AUTOCREATE_DISABLE=\${ZOO_DATADIR_AUTOCREATE_DISABLE:-true}
env CLASSPATH=\$CLASSPATH $STACK_HOME/$COMPONENT_NAME/bin/${upstream_script} "\$@"
EOF
  chmod 755 $wrapper
done

install -d -m 0755 $PREFIX/$STACK_HOME/$COMPONENT_NAME/etc/rc.d/init.d
cp -a $PREFIX/$STACK_HOME/$COMPONENT_NAME/bin/zookeeper-server $PREFIX/$STACK_HOME/$COMPONENT_NAME/etc/rc.d/init.d