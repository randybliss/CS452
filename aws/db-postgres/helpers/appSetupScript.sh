cd /home/ubuntu
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10

#http://www.webupd8.org/2012/01/install-oracle-java-jdk-7-in-ubuntu-via.html
#sudo add-apt-repository -y ppa:webupd8team/java
sudo sh -c "echo deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main > /etc/apt/sources.list.d/webupd8team-java-trusty.list"
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

echo "setting up FamilySearch user" > /home/ubuntu/instanceStatus
sudo groupadd fs
sudo useradd -s /bin/bash -m -d /home/fs -g fs fs
who=`whoami`
if [ "$who" == "ubuntu" ]; then
  sudo su -
fi
cd /home/fs
echo 'Defaults:fs  !requiretty' >> /etc/sudoers
echo 'fs  ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
#echo "export JAVA_HOME=$javahomedir" >> /home/cassandra/.bashrc
mkdir -p /home/fs/.ssh
cp /home/ubuntu/.ssh/authorized_keys /home/fs/.ssh/authorized_keys
chown -R fs:fs /home/fs/.ssh

#determine path to java home
JAVA_PATH=`which javac`;
if ([ -h "${JAVA_PATH}" ]); then
  while([ -h "${JAVA_PATH}" ]); do JAVA_PATH=`readlink "${JAVA_PATH}"`; done
fi
pushd . > /dev/null
cd `dirname ${JAVA_PATH}` > /dev/null
JAVA_DIR=`pwd`;
javaHome=`dirname $JAVA_DIR`
echo $javaHome > /home/fs/javaHome
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

## Increase the default connection handles limit
sudo mkdir -p /etc/security/limits.d
sudo cat <<EOF > /etc/security/limits.d/tf-default.conf
* hard nofile 1000000
* soft nofile 1000000

root hard nofile 1000000
root soft nofile 1000000
EOF

## Append content to /etc/sysctl.conf
sudo cat <<EOF >> /etc/sysctl.conf
# net.core.wmem_max = 131071
net.core.wmem_max = 16777216
# net.core.rmem_max = 131071
net.core.rmem_max = 16777216
# net.ipv4.tcp_wmem = 4096      16384   4194304
net.ipv4.tcp_wmem = 4096        65536   16777216
# net.ipv4.tcp_rmem = 4096      87380   6291456
net.ipv4.tcp_rmem = 4096        87380   16777216

# Size of the queue used when accepting new connections. If the number of
# pending requests overruns the queue then connections will fail.
# net.core.somaxconn = 128
net.core.somaxconn = 4096

# net.core.netdev_max_backlog = 1000
net.core.netdev_max_backlog = 250000
# net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_recycle = 1
# net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_max_syn_backlog = 8192
# net.ipv4.ip_local_port_range = 32768  61000
net.ipv4.ip_local_port_range = 1024     65535
EOF

## Write new rc.local file
sudo cat <<EOF > /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will \"exit 0\" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
/sbin/ifconfig eth0 txqueuelen 4000
/sbin/ifconfig eth0 mtu 9000
exit 0
EOF

sudo chmod +x /etc/rc.local

cat <<EOF > /home/fs/setupTfAppEnv
#!/bin/bash
export JAVA_HOME=`cat /home/fs/javaHome`
export TF_HOME=/home/fs
EOF
chmod +x /home/fs/setupTfAppEnv
echo "source ~/setupTfAppEnv" >> /home/fs/.bashrc
sudo cat <<EOF > /home/fs/.bash_profile
#!/bin/bash
if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi
EOF
chown -R fs:fs /home/fs
sudo cat /home/fs/setupTfAppEnv >> /etc/profile

#disable ipv6 (hadoop doesn't like it)
sudo cat /etc/sysctl.conf > tempfile
echo "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1" >> tempfile
sudo cp tempfile /etc/sysctl.conf
rm tempfile

echo "*************And we're Done!"
echo "ready" > /home/ubuntu/instanceStatus

