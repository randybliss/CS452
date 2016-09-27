cd /home/ubuntu
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10

#http://www.webupd8.org/2012/01/install-oracle-java-jdk-7-in-ubuntu-via.html
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886

echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections

sudo apt-get -y update
sudo apt-get -y install python-setuptools
sudo apt-get -y install python-dateutil

echo "installing Java 8 SDK" > /home/ubuntu/instanceStatus
sudo apt-get -y --force-yes install oracle-java8-installer
javabin=`which java`
javabindir=`dirname $javabin`
javahomedir=`dirname $javabindir`
sudo apt-get -y install unzip

echo "setting up Cassandra user" > /home/ubuntu/instanceStatus
sudo groupadd cassandra
sudo useradd -s /bin/bash -m -d /home/cassandra -g cassandra cassandra
sudo su -
cd /home/cassandra
echo 'Defaults:cassandra  !requiretty' >> /etc/sudoers
echo 'cassandra  ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
#echo "export JAVA_HOME=$javahomedir" >> /home/cassandra/.bashrc
mkdir -p /home/cassandra/.ssh
cp /home/ubuntu/.ssh/authorized_keys /home/cassandra/.ssh/authorized_keys
chown -R cassandra:cassandra /home/cassandra/.ssh

#determine path to java home
JAVA_PATH=`which javac`;
if ([ -h "${JAVA_PATH}" ]); then
  while([ -h "${JAVA_PATH}" ]); do JAVA_PATH=`readlink "${JAVA_PATH}"`; done
fi
pushd . > /dev/null
cd `dirname ${JAVA_PATH}` > /dev/null
JAVA_DIR=`pwd`;
javaHome=`dirname $JAVA_DIR`
echo $javaHome > /home/cassandra/javaHome
echo $javaHome
popd  > /dev/null

echo "installing sysstat, mdadm and pdsh utilities" > /home/ubuntu/instanceStatus
#install sysstat package for opsCenter access
sudo apt-get -y install sysstat

#install mdadm to enable --useRaid capability
sudo apt-get -y install mdadm --no-install-recommends

#install pdsh to enable file propagation to cluster nodes
sudo apt-get -y install pdsh
sudo ln -s /usr/bin/pdcp /usr/local/bin/pdcp

echo "installing JNA" > /home/ubuntu/instanceStatus
#install JNA
sudo apt-get -y install libjna-java

## Increase the default connection handles limit
sudo mkdir -p /etc/security/limits.d
sudo cat <<EOF > /etc/security/limits.d/tf-default.conf
* hard nofile 1000000
* soft nofile 1000000

root hard nofile 1000000
root soft nofile 1000000
EOF

cat <<EOF > /home/cassandra/setupCassandraEnv
#!/bin/bash
export JAVA_HOME=`cat /home/cassandra/javaHome`
export CASSANDRA_HOME=/home/cassandra/cassandraHome
export PATH=$CASSANDRA_HOME/bin:$CASSANDRA_HOME/tools/bin:$PATH
EOF
chmod +x /home/cassandra/setupCassandraEnv
echo "source ~/setupCassandraEnv" >> /home/cassandra/.bashrc
sudo cat <<EOF > /home/cassandra/.bash_profile
#!/bin/bash
if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi
EOF
chown -R cassandra:cassandra /home/cassandra
sudo cat /home/cassandra/setupCassandraEnv >> /etc/profile

#disable ipv6 (hadoop doesn't like it)
sudo cat /etc/sysctl.conf > tempfile
echo "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1" >> tempfile
sudo cp tempfile /etc/sysctl.conf
rm tempfile

echo "*************And we're Done!"
echo "ready" > /home/ubuntu/instanceStatus

