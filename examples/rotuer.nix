# This is not part of Liminix per se. This is my "scratchpad"
# configuration for the device I'm testing with.
#
# Parts of it do do things that Liminix eventually needs to do, but
# don't look in here for solutions - just for identifying the
# problems.


{ config, pkgs, lib, ... } :
let
  secrets = import ./rotuer-secrets.nix;
  inherit (pkgs.liminix.networking)
    address
    dnsmasq
    hostapd
    interface
    pppoe
    route;
  inherit (pkgs.liminix.services) oneshot longrun bundle target;
  inherit (pkgs)
    dropbear
    ifwait
    serviceFns;
in rec {
  boot = {
    tftp = {
      enable = true;
      serverip = "10.0.0.1";
      ipaddr = "10.0.0.8";
    };
  };

  imports = [
    ./modules/wlan.nix
    ./modules/tftpboot.nix
#    ./modules/flashimage.nix
  ];

  kernel = {
    config = {
      PPP = "y";
      PPP_BSDCOMP = "y";
      PPP_DEFLATE = "y";
      PPP_ASYNC = "y";
      PPP_SYNC_TTY = "y";
      BRIDGE = "y";

      NETFILTER_XT_MATCH_CONNTRACK = "y";

      IP6_NF_IPTABLES= "y";     # do we still need these
      IP_NF_IPTABLES= "y";      # if using nftables directly

      IP_NF_NAT = "y";
      IP_NF_TARGET_MASQUERADE = "y";
      NETFILTER = "y";
      NETFILTER_ADVANCED = "y";
      NETFILTER_XTABLES = "y";

      NFT_COMPAT = "y";
      NFT_CT = "y";
      NFT_LOG = "y";
      NFT_MASQ = "y";
      NFT_NAT = "y";
      NFT_REJECT = "y";
      NFT_REJECT_INET = "y";

      NF_CONNTRACK = "y";
      NF_NAT = "y";
      NF_NAT_MASQUERADE  = "y";
      NF_TABLES= "y";
      NF_TABLES_INET = "y";
      NF_TABLES_IPV4 = "y";
      NF_TABLES_IPV6 = "y";
    };
  };

  services.hostap = hostapd (config.hardware.networkInterfaces.wlan_24) {
    params = {
      ssid = "liminix";
      country_code = "GB";
      hw_mode="g";
      channel = "2";
      wmm_enabled = 1;
      ieee80211n = 1;
      inherit (secrets) wpa_passphrase;
      auth_algs = 1; # 1=wpa2, 2=wep, 3=both
      wpa = 2;       # 1=wpa, 2=wpa2, 3=both
      wpa_key_mgmt = "WPA-PSK";
      wpa_pairwise = "TKIP CCMP";   # auth for wpa (may not need this?)
      rsn_pairwise = "CCMP";        # auth for wpa2
    };
  };

  services.hostap5 = hostapd (config.hardware.networkInterfaces.wlan_5) {
    params = rec {
      ssid = "liminix_5";
      country_code = "GB";
      hw_mode="a";
      channel = 36;
      ht_capab = "[HT40+]";
      vht_oper_chwidth = 1;
      vht_oper_centr_freq_seg0_idx = channel + 6;
      ieee80211ac = 1;

      wmm_enabled = 1;
      inherit (secrets) wpa_passphrase;
      auth_algs = 1; # 1=wpa2, 2=wep, 3=both
      wpa = 2;       # 1=wpa, 2=wpa2, 3=both
      wpa_key_mgmt = "WPA-PSK";
      wpa_pairwise = "TKIP CCMP";   # auth for wpa (may not need this?)
      rsn_pairwise = "CCMP";        # auth for wpa2
    };
  };

  services.int =
    let iface = interface {
          type = "bridge";
          device = "int";
        };
    in address iface {
      family = "inet4"; address ="10.8.0.1"; prefixLength = 16;
    };

  services.bridge =
    let
      primary = services.int;
      addif = dev: oneshot {
        name = "add-${dev.device}-to-bridge";
        up = "${ifwait}/bin/ifwait -v ${dev.device} running && ip link set dev ${dev.device} master ${primary.device}";
        down = "ip link set dev ${dev} nomaster";
        dependencies = [ primary dev ];
      };
    in bundle {
      name = "bridge-members";
      contents = with config.hardware.networkInterfaces; map addif [
        wlan_24 lan wlan_5
      ];
    };

  services.sshd = longrun {
    name = "sshd";
    run = ''
      mkdir -p /run/dropbear
      ${dropbear}/bin/dropbear -E -P /run/dropbear.pid -R -F
    '';
  };

  users.dnsmasq = {
    uid = 51; gid= 51; gecos = "DNS/DHCP service user";
    dir = "/run/dnsmasq";
    shell = "/bin/false";
  };
  users.root.passwd = lib.mkForce secrets.root_password;

  groups.dnsmasq = {
    gid = 51; usernames = ["dnsmasq"];
  };
  groups.system.usernames = ["dnsmasq"];

  services.dns =
    dnsmasq {
      resolvconf = services.resolvconf;
      interface = services.int;
      ranges = ["10.8.0.10,10.8.0.240"];
      domain = "fake.liminix.org";
    };

  services.wan =
    let iface = config.hardware.networkInterfaces.wan;
    in pppoe iface {
      ppp-options = [
        "debug" "+ipv6" "noauth"
        "name" secrets.l2tp.name
        "password" secrets.l2tp.password
      ];
    };

  services.resolvconf = oneshot rec {
    dependencies = [ services.wan ];
    name = "resolvconf";
    up = ''
      . ${serviceFns}
      ( in_outputs ${name}
       echo "nameserver $(output ${services.wan} ns1)" > resolv.conf
       echo "nameserver $(output ${services.wan} ns2)" >> resolv.conf
      )
    '';
    down = ''
      rm -rf /run/service-state/${name}/
    '';
  };

  services.defaultroute4 = route {
    name = "defaultroute";
    via = "$(output ${services.wan} address)";
    target = "default";
    dependencies = [ services.wan ];
  };

  services.packet_forwarding =
    let filename = "/proc/sys/net/ipv4/conf/all/forwarding";
    in oneshot {
      name = "let-the-ip-flow";
      up = ''
        ${pkgs.nftables}/bin/nft -f ${./nat.nft}
        echo 1 > ${filename}
      '';
      down = "echo 0 > ${filename}";
    };

  services.default = target {
    name = "default";
    contents = with services; [
      config.hardware.networkInterfaces.lo
      config.hardware.networkInterfaces.lan
      int
      bridge
      hostap
      hostap5
      defaultroute4
      packet_forwarding
      dns
      resolvconf
      sshd
    ];
  };
  defaultProfile.packages = with pkgs;  [ nftables strace tcpdump ] ;
}
