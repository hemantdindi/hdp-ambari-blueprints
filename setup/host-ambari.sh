#!/bin/sh
cd ~
mkdir node-setup
cd node-setup
cp /etc/hosts .
head -2 hosts > /etc/hosts 
ip a | grep 'inet' | grep eth0 | cut -d: -f2 | awk '{ print $2}' | tr "/" " " | awk '{ print $1}' > ipaddr
hostname -f | tr "." " " | awk '{ print $1}' > hostname
hostname -f > fqdn
cat ipaddr fqdn hostname | xargs >> /etc/hosts
service network restart
rm -rf ~/.ssh
mkdir ~/.ssh
ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
ssh -o "StrictHostKeyChecking no" `hostname` 'date'
yum install httpd -y
service httpd start
systemctl enable httpd
service firewalld stop
systemctl disable firewalld
wget -nv http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.4.2.0/ambari.repo -O /etc/yum.repos.d/ambari.repo
yum install ambari-server -y
mkdir -p /usr/share/java
wget -nv https://jdbc.postgresql.org/download/postgresql-9.4.1212.jre6.jar -O /usr/share/java/postgresql-jdbc.jar
ambari-server setup -s 
ambari-server setup --jdbc-db=postgres --jdbc-driver=/usr/share/java/postgresql-jdbc.jar
ambari-server start
yum install ambari-agent -y
sed -i 's/hostname=localhost/'hostname="$HOSTNAME"'/g' /etc/ambari-agent/conf/ambari-agent.ini
ambari-agent start
export realm=`hostname -d`
export REALM="${realm^^}"
export KDC_HOST=`hostname -f`
yum -y install krb5-server krb5-libs krb5-workstation
cp /etc/krb5.conf .
sed -i "s/EXAMPLE.COM/$REALM/g" krb5.conf
sed -i "s/example.com/$realm/g" krb5.conf
sed -i "s/kerberos.$realm/$KDC_HOST/g" krb5.conf
sed -i '2,$s/#//' krb5.conf
cp krb5.conf /etc/krb5.conf
kdb5_util create -s -P hadoop
service krb5kdc start
service kadmin start
systemctl enable krb5kdc
systemctl enable kadmin
kadmin.local -q "addprinc -pw hadoop admin/admin"
sed -i "s/EXAMPLE.COM/$REALM/g" /var/kerberos/krb5kdc/kadm5.acl
service krb5kdc restart
service kadmin restart
service postgresql restart
su postgres -c psql <<EOF
\x
create database hivedb;
create user hiveuser with password 'hadoop';
grant all privileges on database hivedb to hiveuser;
EOF
echo "host all all 0.0.0.0/0 trust" >> /var/lib/pgsql/data/pg_hba.conf
service postgresql restart
passwd root <<EOF
hadoophdp
hadoophdp
EOF