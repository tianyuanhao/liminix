{
  liminix
, dnsmasq
, serviceFns
, lib
}:
{
  user ? "dnsmasq"
, group ? "system"
, resolvconf ? null
, interface
, upstreams ? []
, ranges
, domain
} :
let
  inherit (liminix.services) longrun;
  inherit (lib) concatStringsSep;
  name = "${interface.device}.dnsmasq";
in longrun {
  inherit name;
  dependencies = [ interface ];
  run = ''
    . ${serviceFns}
    ${dnsmasq}/bin/dnsmasq \
    --user=${user} \
    --domain=${domain} \
    --group=${group} \
    --interface=${interface.device} \
    ${lib.concatStringsSep " " (builtins.map (r: "--dhcp-range=${r}") ranges)} \
    ${lib.concatStringsSep " " (builtins.map (r: "--server=${r}") upstreams)} \
    --keep-in-foreground \
    --dhcp-authoritative \
    ${if resolvconf != null then "--resolv-file=$(output_path ${resolvconf} resolv.conf)" else "--no-resolv"} \
    --no-hosts \
    --log-dhcp \
    --enable-ra \
    --log-debug \
    --log-queries \
    --log-facility=- \
    --dhcp-leasefile=/run/${name}.leases \
    --pid-file=/run/${name}.pid
  '';
}
