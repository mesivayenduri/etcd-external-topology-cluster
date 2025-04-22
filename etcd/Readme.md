Create 3 new vms in Oracle VM with either ubuntu/centos

Hostname | IP
etcd-node-1 | 192.168.56.1/24
etcd-node-2 | 192.168.56.2/24
etcd-node-3 | 192.168.56.3/24

```graph
192.168.56.1/24  192.168.56.2/24   192.168.56.3/24
[etcd-node-1]     [etcd-node-2]     [etcd-node-3]
     |                  |                  |
     +------------------+------------------+
                        |
               [kube-apiserver]
```

etcdctl --endpoints=http://192.168.56.101:2379,http://192.168.56.102:2379,http://192.168.56.103:2379 endpoint health

etcdctl --endpoints=http://192.168.56.101:2379 member list

# SECURING CLUSTER : Enable TLS

We’ll go step-by-step:

-> Generate a CA (self-signed root certificate)

-> Create a proper OpenSSL config file for SANs

-> Generate etcd node keys + CSRs

-> Sign CSRs using our CA to get final certs

-> Copy certs to each etcd node


etcd-node-1:

```bash
mkdir -p ~/etcd-certs
cd ~/etcd-certs

openssl genrsa -out ca.key 4096

openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=etcd-ca"

openssl genrsa -out etcd-node-1.key 2048

openssl req -new -key etcd-node-1.key -out etcd-node-1.csr \
  -config etcd-node-1-openssl.cnf

openssl x509 -req -in etcd-node-1.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out etcd-node-1.crt -days 3650 -sha256 -extensions req_ext \
  -extfile etcd-node-1-openssl.cnf


scp ca.crt etcd-node-1.key etcd-node-1.crt vagrant@192.168.56.101:/home/vagrant/

sudo useradd -r -s /sbin/nologin etcd
sudo mkdir -p /etc/etcd/pki
sudo mv /home/vagrant/*.crt /home/vagrant/*.key /etc/etcd/pki/
sudo chown -R etcd:etcd /etc/etcd/pki
sudo chmod 600 /etc/etcd/pki/etcd-node-1.key
sudo chmod 644 /etc/etcd/pki/etcd-node-1.crt
sudo chmod 644 /etc/etcd/pki/ca.crt


sudo nano /etc/systemd/system/etcd.service


[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd
After=network.target

[Service]
User=etcd
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name etcd-node-1 \
  --data-dir /var/lib/etcd \
  --initial-advertise-peer-urls https://192.168.56.101:2380 \
  --listen-peer-urls https://192.168.56.101:2380 \
  --listen-client-urls https://192.168.56.101:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://192.168.56.101:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster \
      etcd-node-1=https://192.168.56.101:2380,\
      etcd-node-2=https://192.168.56.102:2380,\
      etcd-node-3=https://192.168.56.103:2380 \
  --initial-cluster-state new \
  --cert-file=/etc/etcd/pki/etcd-node-1.crt \
  --key-file=/etc/etcd/pki/etcd-node-1.key \
  --peer-cert-file=/etc/etcd/pki/etcd-node-1.crt \
  --peer-key-file=/etc/etcd/pki/etcd-node-1.key \
  --trusted-ca-file=/etc/etcd/pki/ca.crt \
  --peer-trusted-ca-file=/etc/etcd/pki/ca.crt

Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target



sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart etcd


sudo systemctl status etcd


export ETCDCTL_API=3

etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/pki/ca.crt \
  --cert=/etc/etcd/pki/etcd-node-1.crt \
  --key=/etc/etcd/pki/etcd-node-1.key \
  endpoint health
```


etcd-node-2:

```bash
openssl genrsa -out etcd-node-2.key 2048

openssl req -new -key etcd-node-2.key \
  -out etcd-node-2.csr \
  -config etcd-node-2-openssl.cnf

openssl x509 -req -in etcd-node-2.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out etcd-node-2.crt -days 365 \
  -extensions req_ext -extfile etcd-node-2-openssl.cnf


scp etcd-node-2.key etcd-node-2.crt ca.crt vagrant@192.168.56.102:/home/vagrant/


sudo mkdir -p /etc/etcd/pki
sudo mv ~/etcd-node-2.key ~/etcd-node-2.crt ~/ca.crt /etc/etcd/pki/
sudo chown -R etcd:etcd /etc/etcd/pki
sudo chmod 600 /etc/etcd/pki/etcd-node-2.key
sudo chmod 644 /etc/etcd/pki/etcd-node-2.crt /etc/etcd/pki/ca.crt


sudo nano /etc/systemd/system/etcd.service


[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd
After=network.target

[Service]
User=etcd
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name etcd-node-2 \
  --data-dir /var/lib/etcd \
  --initial-advertise-peer-urls https://192.168.56.102:2380 \
  --listen-peer-urls https://192.168.56.102:2380 \
  --listen-client-urls https://192.168.56.102:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://192.168.56.102:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster \
      etcd-node-1=https://192.168.56.101:2380,\
      etcd-node-2=https://192.168.56.102:2380,\
      etcd-node-3=https://192.168.56.103:2380 \
  --initial-cluster-state new \
  --cert-file=/etc/etcd/pki/etcd-node-2.crt \
  --key-file=/etc/etcd/pki/etcd-node-2.key \
  --peer-cert-file=/etc/etcd/pki/etcd-node-2.crt \
  --peer-key-file=/etc/etcd/pki/etcd-node-2.key \
  --trusted-ca-file=/etc/etcd/pki/ca.crt \
  --peer-trusted-ca-file=/etc/etcd/pki/ca.crt

Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

```


```bash
openssl genrsa -out etcd-node-3.key 2048

openssl req -new -key etcd-node-3.key \
  -out etcd-node-3.csr \
  -config etcd-node-3-openssl.cnf


openssl x509 -req -in etcd-node-3.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out etcd-node-3.crt -days 365 \
  -extensions req_ext -extfile etcd-node-3-openssl.cnf

scp etcd-node-3.key etcd-node-3.crt ca.crt vagrant@192.168.56.103:/home/vagrant/


sudo mkdir -p /etc/etcd/pki
sudo mv ~/etcd-node-3.key ~/etcd-node-3.crt ~/ca.crt /etc/etcd/pki/
sudo chown -R etcd:etcd /etc/etcd/pki
sudo chmod 600 /etc/etcd/pki/etcd-node-3.key
sudo chmod 644 /etc/etcd/pki/etcd-node-3.crt /etc/etcd/pki/ca.crt


sudo nano /etc/systemd/system/etcd.service


[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd
After=network.target

[Service]
User=etcd
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name etcd-node-3 \
  --data-dir /var/lib/etcd \
  --initial-advertise-peer-urls https://192.168.56.103:2380 \
  --listen-peer-urls https://192.168.56.103:2380 \
  --listen-client-urls https://192.168.56.103:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://192.168.56.103:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster \
      etcd-node-1=https://192.168.56.101:2380,\
      etcd-node-2=https://192.168.56.102:2380,\
      etcd-node-3=https://192.168.56.103:2380 \
  --initial-cluster-state new \
  --cert-file=/etc/etcd/pki/etcd-node-3.crt \
  --key-file=/etc/etcd/pki/etcd-node-3.key \
  --peer-cert-file=/etc/etcd/pki/etcd-node-3.crt \
  --peer-key-file=/etc/etcd/pki/etcd-node-3.key \
  --trusted-ca-file=/etc/etcd/pki/ca.crt \
  --peer-trusted-ca-file=/etc/etcd/pki/ca.crt

Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

```

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

etcdctl --endpoints="https://192.168.56.101:2379,https://192.168.56.102:2379,https://192.168.56.103:2379" \
  --cacert=/etc/etcd/pki/ca.crt \
  --cert=/etc/etcd/pki/etcd-node-1.crt \
  --key=/etc/etcd/pki/etcd-node-1.key \
  endpoint status --write-out=table



etcdctl --endpoints="https://192.168.56.101:2379" \
  --cacert=/etc/etcd/pki/ca.crt \
  --cert=/etc/etcd/pki/etcd-node-1.crt \
  --key=/etc/etcd/pki/etcd-node-1.key \
  put hey "hello"

etcdctl --endpoints="https://192.168.56.103:2379" \
  --cacert=/etc/etcd/pki/ca.crt \
  --cert=/etc/etcd/pki/etcd-node-3.crt \
  --key=/etc/etcd/pki/etcd-node-3.key \
  get hey

```