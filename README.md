# Liminix

A Nix-based system for configuring consumer wifi routers or IoT device
devices, of the kind that OpenWrt or DD-WRT or Gargoyle or Tomato run
on. It's a reboot/restart/rewrite of NixWRT.

This is not NixOS-on-your-router: it's aimed at devices that are
underpowered for the full NixOS experience. It uses busybox tools,
musl instead of GNU libc, and s6-rc instead of systemd.

The Liminix name comes from Liminis, in Latin the genitive declension
of "limen", or "of the threshold". Your router stands at the threshold
of your (online) home and everything you send to/receive from the
outside word goes across it.

## What about NixWRT?

This is an in-progress rewrite of NixWRT, incorporating Lessons
Learned.

## Documentation

Documentation is in the [doc](doc/) directory. You can build it
by running

    nix-shell -p sphinx --run "make -C doc html"


## Extremely online

There is a #liminix IRC channel on the [OFTC](https://www.oftc.net/)
network in which you are welcome. You can also connect with a Matrix
client by joining the room `#_oftc_#liminix:matrix.org`.

In the IRC channel, as in all Liminix project venues, please conduct yourself
according to the Liminix [Code of Conduct](CODE-OF-CONDUCT.md).
