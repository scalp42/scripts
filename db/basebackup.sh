#/bin/sh -x
#
# XXX We assume master and recovery host uses the same port number
PORT=5432
master_node_host_name=`hostname`
master_db_cluster=$1
recovery_node_host_name=$2
recovery_db_cluster=$3
tmp=/tmp/mytemp$$
echo "received parameters: $master_db_cluster , $recovery_node_host_name , $recovery_db_cluster" > /tmp/base.log
trap "rm -f $tmp" 0 1 2 3 15

psql -p $PORT -c "SELECT pg_start_backup('Streaming Replication', true)" postgres
echo "done select" >> /tmp/base.log

rsync -C -a -c --delete --exclude postgresql.conf --exclude postmaster.pid \
--exclude postmaster.opts --exclude pg_log \
--exclude recovery.conf --exclude recovery.done \
--exclude pg_xlog \
$master_db_cluster/ $recovery_node_host_name:$recovery_db_cluster

echo "done rsync" >> /tmp/base.log
ssh -T $recovery_node_host_name mkdir $recovery_db_cluster/pg_xlog
ssh -T $recovery_node_host_name chmod 700 $recovery_db_cluster/pg_xlog
ssh -T $recovery_node_host_name rm -f $recovery_db_cluster/recovery.done

echo "done ssh" >> /tmp/base.log
cat > $tmp <<EOF
standby_mode          = 'on'
primary_conninfo      = 'host=$master_node_host_name port=$PORT user=postgres'
trigger_file = '/var/log/pgpool/trigger/trigger_file1'
EOF

echo "done cat" >> /tmp/base.log
scp $tmp $recovery_node_host_name:$recovery_db_cluster/recovery.conf

echo "done scp" >> /tmp/base.log
psql -p $PORT -c "SELECT pg_stop_backup()" postgres

