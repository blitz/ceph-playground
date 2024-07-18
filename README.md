

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
