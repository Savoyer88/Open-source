Setting up MySQL Database using 3 node Percona XtraDB Cluster on Ubuntu 18.04 servers in EC2

Created a MySQL schema 

DB node1 - writer, nodes 2,3 - readers (multi-AZ) + node4 in a different region for availability (Master-Slave replication using SSL certs)

CloudWatch metric on DB node1 that monitors disk usage and a cronjob which runs the command every 5min

Using Lambda (python) on AWS, write a script that will use the disk usage metric you set up 
Lambda script creates an alarm in CloudWatch when the disk space on DB node1 exceeds 50% 
