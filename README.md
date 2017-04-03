# cicd
A set of compose files to quickly bootstrap CI/CD pipelines, chain log and monitoring tools on a Docker Swarm cluster.

## Start CI pipeline

```
docker swarm init
# We'll get rid of next line when compose file will support --attachable flag
docker network create --attachable -d overlay ci_ci-network
docker network create -d overlay monitoring_monitoring-network
```

Start the services:
```
export DOMAIN=localhost       # (or example.com)
docker stack up -c ci.yml ci
docker stack up -c monitoring.yml monitoring
docker stack up -c front.yml front
# or just 
make
```

Then visit `localhost:8000` to get gogs/drone url.

## Grafana dashboards
https://grafana.com/dashboards/395

https://grafana.com/dashboards/405

## Cluster bootstrap
In the `cluster-bootstrap` are a packer template for an ubuntu 16.04 with docker 17.03.0~ce, Ceph jewel and rexray volume driver installed.

The following commands are notes to bootstrap a Vagrant cluster from this packer template, set-up a 3-nodes Swarm cluster with cluster-aware volume mounting thanks to Ceph and RexRay driver. This way we have full HA at every level.

Those notes should probably be part of an ansible playbook.

### Building VM image and starting the nodes
```
packer build cluster-bootstrap/packer/ubuntu-16.04-amd64.json
vagrant box add ael/cicd-os cluster-bootstrap/packer/ubuntu-16.04-amd64-virtualbox.box
cd cluster-bootstrap
vagrant plugin install vagrant-hosts
vagrant up
```

### Ceph cluster setup
You need to have `ceph-deploy` installed on your local machine.
We're using loop files here to provide block devices. This is obvisously an easy way to test and not a production setup.
EBS for Amazon or anything similar on other cloud providers should be used instead.

```
vagrant ssh-config node1 node2 node3 >> ~/.ssh/config
ceph-deploy new node1 node2 node3
echo public_network = 192.168.10.0/24 >> ceph.conf
ceph-deploy mon create node1 node2 node3
sleep 10
ceph-deploy gatherkeys node1
ssh node1 sudo sh -c "\"dd if=/dev/zero of=/var/lib/osd bs=1M count=10000 && losetup /dev/loop0 /var/lib/osd\""
ceph-deploy osd create node1:/dev/loop0 node2:/dev/loop0 node3:/dev/loop0
```

### RexRay setup
At the moment (3/17/2017) RexRay is broken when used with Ceph's Jewel and Kraken version.
A PR which fix that is available but you need to build rexray with the patch included (https://github.com/codedellemc/libstorage/pull/454/)

To do on all 3 nodes:
```
cat > /etc/rexray.yml <<EOF
rexray:
  logLevel: warn
libstorage:
  service: rbd
rbd:
EOF

rexray service start
```

### Docker Swarm setup
```
vagrant@node1:~$ sudo docker swarm init --advertise-addr 192.168.10.101

vagrant@node2:~$ sudo docker swarm join --token YOUR_TOKEN 192.168.10.101:2377
vagrant@node3:~$ sudo docker swarm join --token YOUR_TOKEN 192.168.10.101:2377
```

### Ready to play

We'll test if we can write data to a volume on container started on one node, start the container on another node and check if data are still there.

Let's start by creating a service with a rexray volume :
```
vagrant@node1:~$ sudo docker service create --mount source=mydata,target=/data,volume-driver=rexray \
johntech2006/randomcity
1kj26xhj2y45g4cwifmh1ohik
```

Check where it's deployed
```
vagrant@node1:~$ sudo docker service ps 1kj26xhj2y45g4cwifmh1ohik
ID            NAME                  IMAGE                           NODE   DESIRED STATE  CURRENT STATE           ERROR  PORTS
mzl6qf41v8zx  xenodochial_edison.1  johntech2006/randomcity:latest  node2  Running        Running 39 seconds ago
```

Enter the container on the node2 and write some data
```
vagrant@node2:~$ sudo docker ps -q
07605b5c13d6
vagrant@node2:~$ sudo docker exec -it 07605b5c13d6 sh -c "touch /data/imstillthere"
```

Stop docker daemon on node2, swarm will automatically restart the container elsewhere
```
vagrant@node2:~$ sudo service docker stop
vagrant@node1:~$ sudo docker service ps 1kj26xhj2y45g4cwifmh1ohik
ID            NAME                      IMAGE                           NODE   DESIRED STATE  CURRENT STATE           ERROR  PORTS
xzp9iscbzqkh  xenodochial_edison.1      johntech2006/randomcity:latest  node3  Running        Running 1 second ago
mzl6qf41v8zx   \_ xenodochial_edison.1  johntech2006/randomcity:latest  node2  Shutdown       Running 19 seconds ago
```

Check that data are still there on node3
```
vagrant@node3:~$ sudo docker exec -it e4b6ddd8af2e sh -c "ls /data"
imstillthere
```
