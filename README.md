# Ceph playground

This repository contains a NixOS integration test that setups up a Ceph cluster with two clients.

The clients have been configured with scripts that launch [virtiofsd](https://gitlab.com/virtio-fs/virtiofsd)
with the ceph filesystem as the shared filesystem together with QEMU VMs that have access to the shared filesystem
via VirtioFS. These scripts are currently only intended to be executed when running the NiXOS integration test interactively,
and are not part of the test itself.

## Live migration PoC

Build the test to run interactively

```bash
$ nix -L build .\#checks.x86_64-linux.ceph.driverInteractive
```

then run the test in interactive mode with

```bash
$ ./result/bin/nixos-test-driver
```

Now start the Ceph cluster by simply running the full test by calling

```bash
test_script()
```

wait until you see login screens for both the client VMs (client1 and client2).

Login and open a shell in client1. 

In client1's terminal execute

```bash
$ start-sender-vm
```

this spawns virtiofsd with the Ceph filesystem as the shared filesystem and
launches a QEMU VM that boots from the NixOS live cd (you may just wait until you see a promt
now). Once we obtain a promt we want to mount the ceph filesystem. First create the mount with

```bash
$ sudo mkdir /mnt/cephfs
```

then we mount the cephfs filesystem

```bash
$ sudo mount -t virtiofs myfs /mnt/cephfs
```

and we write our testfile there

```bash
$ echo "Hello world!" | sudo tee /mnt/cephfs/foo
```

we will now run a preinstalled program that
reads and prints the read contents in a loop
as our VM workload.

```bash
$virtiofs-test
```

Now in client2's terminal execute

```bash
$ start-receiver-vm
```
which will then wait for an incoming migration.




Attach virtiofs at runtime:

```
sudo virtiofsd --socket-path=/tmp/vsd.sock --shared-dir /tmp --announce-submounts --inode-file-handles=mandatory
```


Qemu monitor:

```
chardev-add socket,id=char0,path=/tmp/vsd.sock
device_add vhost-user-fs-pci,chardev=char0,tag=myfs
```

Fails with:

```
❯ sudo virtiofsd --socket-path=/tmp/vsd.sock --shared-dir /tmp --announce-submounts --inode-file-handles=mandatory
[2024-07-18T12:53:55Z INFO  virtiofsd] Waiting for vhost-user socket connection...
[2024-07-18T12:57:08Z INFO  virtiofsd] Client connected, servicing requests
[2024-07-18T12:57:14Z ERROR virtiofsd] Waiting for daemon failed: HandleRequest(InvalidParam)

```


```
(qemu) chardev-add socket,id=char0,path=/tmp/vsd.sock
(qemu) device_add vhost-user-fs-pci,chardev=char0,tag=myfs
(qemu) qemu: Failed to read msg header. Read -1 instead of 12. Original request 0.
qemu: Failed to write msg. Wrote -1 instead of 20.
qemu: vhost VQ 1 ring restore failed: -22: Invalid argument (22)
qemu: Failed to set msg fds.
qemu: vhost VQ 0 ring restore failed: -22: Invalid argument (22)
qemu: Error starting vhost: 5
qemu: Failed to set msg fds.
qemu: vhost_set_vring_call failed 22
qemu: Failed to set msg fds.
qemu: vhost_set_vring_call failed 22
qemu: Unexpected end-of-file before all data were read

```
