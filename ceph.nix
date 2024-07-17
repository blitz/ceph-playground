{
  pkgs, lib, ...
}:

let
  cfg = {
    clusterId = "066ae264-2a5d-4729-8001-6ad265f50b03";
    monA = {
      name = "a";
      ip = "192.168.1.1";
    };
    osd0 = {
      name = "0";
      key = "AQBCEJNa3s8nHRAANvdsr93KqzBznuIWm2gOGg==";
      uuid = "55ba2294-3e24-478f-bee0-9dca4c231dd9";
    };
    osd1 = {
      name = "1";
      key = "AQBEEJNac00kExAAXEgy943BGyOpVH1LLlHafQ==";
      uuid = "5e97a838-85b6-43b0-8950-cb56d554d1e5";
    };
    osd2 = {
      name = "2";
      key = "AQAdyhZeIaUlARAAGRoidDAmS6Vkp546UFEf5w==";
      uuid = "ea999274-13d0-4dd5-9af9-ad25a324f72f";
    };
    mds0 = {
      name = "a";
      key = "AQAdyhZeIaUlARAAGRoidDAmS6Vkp546UFEf5w=="; # TODO should be distinct...
      uuid = "1baac704-c053-445c-841d-1b075fa8b8aa";
    };
  };
  generateCephConfig = { daemonConfig }: {
    enable = true;
    global = {
      fsid = cfg.clusterId;
      monHost = cfg.monA.ip;
      monInitialMembers = cfg.monA.name;
      #authClientRequired = "none";
    };
    client.enable = true;
  } // daemonConfig;

  generateHost = { pkgs, cephConfig, networkConfig, ... }: {
    virtualisation = {
      emptyDiskImages = [ 20480 20480 20480 ];
      vlans = [ 1 ];

      # Go fast.
      cores = 4;
    };

    networking = networkConfig;

    environment.systemPackages = with pkgs; [
      bash
      sudo
      ceph
      xfsprogs
    ];

    boot.kernelModules = [ "xfs" ];

    services.ceph = cephConfig;
  };

  networkMonA = {
    firewall.enable = false;
    dhcpcd.enable = false;
    interfaces.eth1.ipv4.addresses = pkgs.lib.mkOverride 0 [
      { address = cfg.monA.ip; prefixLength = 24; }
    ];
  };
  cephConfigMonA = generateCephConfig { daemonConfig = {
    mon = {
      enable = true;
      daemons = [ cfg.monA.name ];
    };
    mgr = {
      enable = true;
      daemons = [ cfg.monA.name ];
    };
    osd = {
      enable = true;
      daemons = [ cfg.osd0.name cfg.osd1.name cfg.osd2.name ];
    };
    mds = {
      enable = true;
      daemons = [
        cfg.mds0.name
      ];
    };
  }; };

  # Following deployment is based on the manual deployment described here:
  # https://docs.ceph.com/docs/master/install/manual-deployment/
  # For other ways to deploy a ceph cluster, look at the documentation at
  # https://docs.ceph.com/docs/master/
  testscript = { ... }: ''
    monA.start()

    monA.wait_for_unit("network.target")

    # Bootstrap ceph-mon daemon
    monA.succeed(
        "sudo -u ceph ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'",
        "sudo -u ceph ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'",
        "sudo -u ceph ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring",
        "monmaptool --create --add ${cfg.monA.name} ${cfg.monA.ip} --fsid ${cfg.clusterId} /tmp/monmap",
        "sudo -u ceph ceph-mon --mkfs -i ${cfg.monA.name} --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring",
        "sudo -u ceph touch /var/lib/ceph/mon/ceph-${cfg.monA.name}/done",
        "systemctl start ceph-mon-${cfg.monA.name}",
    )
    monA.wait_for_unit("ceph-mon-${cfg.monA.name}")
    monA.succeed("ceph mon enable-msgr2")
    monA.succeed("ceph config set mon auth_allow_insecure_global_id_reclaim false")

    # Can't check ceph status until a mon is up
    monA.succeed("ceph -s | grep 'mon: 1 daemons'")

    # Start the ceph-mgr daemon, after copying in the keyring
    monA.succeed(
        "sudo -u ceph mkdir -p /var/lib/ceph/mgr/ceph-${cfg.monA.name}/",
        "ceph auth get-or-create mgr.${cfg.monA.name} mon 'allow profile mgr' osd 'allow *' mds 'allow *' > /var/lib/ceph/mgr/ceph-${cfg.monA.name}/keyring",
        "systemctl start ceph-mgr-${cfg.monA.name}",
    )
    monA.wait_for_unit("ceph-mgr-a")
    monA.wait_until_succeeds("ceph -s | grep 'quorum ${cfg.monA.name}'")
    monA.wait_until_succeeds("ceph -s | grep 'mgr: ${cfg.monA.name}(active,'")

    # Bootstrap MDSs
    monA.succeed(
        "mkdir -p /var/lib/ceph/mds/ceph-${cfg.mds0.name}",
        "ceph auth get-or-create mds.${cfg.mds0.name} mon 'profile mds' mgr 'profile mds' mds 'allow *' osd 'allow *' > /var/lib/ceph/mds/ceph-${cfg.mds0.name}/keyring",
        "systemctl start ceph-mds-${cfg.mds0.name}",
    )

    # Bootstrap OSDs
    monA.succeed(
        "mkfs.xfs /dev/vdb",
        "mkfs.xfs /dev/vdc",
        "mkfs.xfs /dev/vdd",
        "mkdir -p /var/lib/ceph/osd/ceph-${cfg.osd0.name}",
        "mount /dev/vdb /var/lib/ceph/osd/ceph-${cfg.osd0.name}",
        "mkdir -p /var/lib/ceph/osd/ceph-${cfg.osd1.name}",
        "mount /dev/vdc /var/lib/ceph/osd/ceph-${cfg.osd1.name}",
        "mkdir -p /var/lib/ceph/osd/ceph-${cfg.osd2.name}",
        "mount /dev/vdd /var/lib/ceph/osd/ceph-${cfg.osd2.name}",
        "ceph-authtool --create-keyring /var/lib/ceph/osd/ceph-${cfg.osd0.name}/keyring --name osd.${cfg.osd0.name} --add-key ${cfg.osd0.key}",
        "ceph-authtool --create-keyring /var/lib/ceph/osd/ceph-${cfg.osd1.name}/keyring --name osd.${cfg.osd1.name} --add-key ${cfg.osd1.key}",
        "ceph-authtool --create-keyring /var/lib/ceph/osd/ceph-${cfg.osd2.name}/keyring --name osd.${cfg.osd2.name} --add-key ${cfg.osd2.key}",
        'echo \'{"cephx_secret": "${cfg.osd0.key}"}\' | ceph osd new ${cfg.osd0.uuid} -i -',
        'echo \'{"cephx_secret": "${cfg.osd1.key}"}\' | ceph osd new ${cfg.osd1.uuid} -i -',
        'echo \'{"cephx_secret": "${cfg.osd2.key}"}\' | ceph osd new ${cfg.osd2.uuid} -i -',
    )

    # Initialize the OSDs with regular filestore
    monA.succeed(
        "ceph-osd -i ${cfg.osd0.name} --mkfs --osd-uuid ${cfg.osd0.uuid}",
        "ceph-osd -i ${cfg.osd1.name} --mkfs --osd-uuid ${cfg.osd1.uuid}",
        "ceph-osd -i ${cfg.osd2.name} --mkfs --osd-uuid ${cfg.osd2.uuid}",
        "chown -R ceph:ceph /var/lib/ceph/osd",
        "systemctl start ceph-osd-${cfg.osd0.name}",
        "systemctl start ceph-osd-${cfg.osd1.name}",
        "systemctl start ceph-osd-${cfg.osd2.name}",
    )
    monA.wait_until_succeeds("ceph osd stat | grep -e '3 osds: 3 up[^,]*, 3 in'")
    monA.wait_until_succeeds("ceph -s | grep 'mgr: ${cfg.monA.name}(active,'")
    monA.wait_until_succeeds("ceph -s | grep 'HEALTH_OK'")

    monA.succeed(
        "ceph osd pool create single-node-test 32 32",
        "ceph osd pool ls | grep 'single-node-test'",

        # We need to enable an application on the pool, otherwise it will
        # stay unhealthy in state POOL_APP_NOT_ENABLED.
        # Creating a CephFS would do this automatically, but we haven't done that here.
        # See: https://docs.ceph.com/en/reef/rados/operations/pools/#associating-a-pool-with-an-application
        # We use the custom application name "nixos-test" for this.
        "ceph osd pool application enable single-node-test nixos-test",

        "ceph osd pool rename single-node-test single-node-other-test",
        "ceph osd pool ls | grep 'single-node-other-test'",
    )
    monA.wait_until_succeeds("ceph -s | grep '2 pools, 33 pgs'")
    monA.succeed(
        "ceph osd getcrushmap -o crush",
        "crushtool -d crush -o decrushed",
        "sed 's/step chooseleaf firstn 0 type host/step chooseleaf firstn 0 type osd/' decrushed > modcrush",
        "crushtool -c modcrush -o recrushed",
        "ceph osd setcrushmap -i recrushed",
        "ceph osd pool set single-node-other-test size 2",
    )
    monA.wait_until_succeeds("ceph -s | grep 'HEALTH_OK'")
    monA.wait_until_succeeds("ceph -s | grep '33 active+clean'")

    monA.succeed(
        "ceph osd pool create cephfs_data 128",
        "ceph osd pool set cephfs_data bulk true",
        "ceph osd pool create cephfs_metadata 32",
        "ceph fs new cephfs cephfs_metadata cephfs_data",
    )

    monA.succeed(
        "ceph fs authorize cephfs client.bob / rw",
        "ceph auth print-key client.bob > bob.key"
    );

    bob_key = monA.succeed("ceph auth print-key client.bob")

    # monA.succeed(
    #     "sudo mkdir -p /mnt/cephfs",
    #     "sudo mount.ceph bob@.cephfs=/ /mnt/cephfs -o secretfile=bob.key",
    # )

    client1.start()
    client2.start()

    client1.wait_for_unit("network.target")
    client2.wait_for_unit("network.target")

    client1.succeed(
        "sudo mkdir -p /mnt/cephfs",
        f"sudo mount.ceph bob@.cephfs=/ /mnt/cephfs -o secret='{bob_key}'",
    )

    client2.succeed(
        "sudo mkdir -p /mnt/cephfs",
        f"sudo mount.ceph bob@.cephfs=/ /mnt/cephfs -o secret='{bob_key}'",
    )
  '';

  generateClient = ip: { pkgs, lib, ... }: {

    networking.firewall.enable = false;
    networking.dhcpcd.enable = false;
    networking.interfaces.eth1.ipv4.addresses = pkgs.lib.mkOverride 0 [
      { address = ip; prefixLength = 24; }
    ];

    services.ceph = {
      enable = true;
      global = {
        fsid = cfg.clusterId;
        monHost = cfg.monA.ip;
        monInitialMembers = cfg.monA.name;
      };
      client.enable = true;
    };

    environment.systemPackages = with pkgs; [
      ceph
      qemu
      virtiofsd
    ];
  };
in {
  name = "basic-single-node-ceph-cluster";
  meta = with pkgs.lib.maintainers; {
    maintainers = [ lejonet johanot ];
  };

  nodes = {
    monA = generateHost { pkgs = pkgs; cephConfig = cephConfigMonA; networkConfig = networkMonA; };

    client1 = generateClient "192.168.1.2";
    client2 = generateClient "192.168.1.3";
  };

  interactive.nodes = {
    client1 = {...}: {
    users.extraUsers.root.initialPassword = "";
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PermitEmptyPasswords = "yes";
      };
    };
    security.pam.services.sshd.allowNullPassword = true;
    virtualisation.forwardPorts = [
      { from = "host"; host.port = 2225; guest.port = 22; }
    ];
  };
  
  client2 = {...}: {
    users.extraUsers.root.initialPassword = "";

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PermitEmptyPasswords = "yes";
      };
    };
    security.pam.services.sshd.allowNullPassword = true;
    virtualisation.forwardPorts = [
      { from = "host"; host.port = 2224; guest.port = 22; }
    ];
    };
  };

  testScript = testscript;
}
