#!/usr/bin/env bash
# List USB devices that expose a serial-ish interface and say how Chrome (Web Serial) will see them.
# Read-only: only reads /sys/bus/usb/devices.

for dev in /sys/bus/usb/devices/[0-9]*; do
  [ -f "$dev/idVendor" ] || continue
  case "$(basename "$dev")" in *:*) continue ;; esac   # skip interface nodes

  vid=$(<"$dev/idVendor"); pid=$(<"$dev/idProduct")
  prod=$(cat "$dev/product" 2>/dev/null); mfr=$(cat "$dev/manufacturer" 2>/dev/null)
  bus_port=$(basename "$dev")

  # interface classes + drivers + tty nodes
  classes=""; drivers=""; ttys=""
  for intf in "$dev":*; do
    [ -f "$intf/bInterfaceClass" ] || continue
    classes+="$(<"$intf/bInterfaceClass") "
    [ -L "$intf/driver" ] && drivers+="$(basename "$(readlink "$intf/driver")") "
    for t in "$intf"/tty/* "$intf"/ttyUSB* "$intf"/ttyACM*; do
      [ -e "$t" ] && ttys+="$(basename "$t") "
    done
  done

  # only report devices that look serial-related
  case "$vid" in
    1a86|10c4|0403|067b) verdict="vendor bridge (CH34x/CP210x/FTDI/PL2303) - depends on Chrome's per-chip support" ;;
    *) if [[ " $classes " == *" 02 "* ]]; then
         verdict="CDC-ACM - standard, should be listed by Chrome"
       elif [[ " $classes " == *" 0a "* ]]; then
         verdict="CDC-Data only"
       elif [[ " $classes " == *" ff "* && -n "$ttys" ]]; then
         verdict="vendor-specific class with a tty"
       else
         continue
       fi ;;
  esac

  printf '%-8s %s:%s  %s %s\n' "$bus_port" "$vid" "$pid" "$mfr" "$prod"
  printf '         classes: %s| drivers: %s| tty: %s\n' "$classes" "$drivers" "$ttys"
  printf '         -> %s\n\n' "$verdict"
done
