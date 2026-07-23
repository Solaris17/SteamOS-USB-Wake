<h1 align="center">SteamOS USB Wake</h1>

> [!NOTE]
> *This tool and its author are not affiliated with Valve in any way.*

> [!TIP]
> **Please do not request install help in this repo!**
## About

This script installs and activates a service that enables Linux USB wake controls for currently exposed USB devices and hubs with a writable ```power/wakeup``` setting.

[SteamOS](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3) is installed by enthusiasts on DIY PCs to create console-like Steam machines.

Most controllers do not send the same remote-wake event as keyboards and mice. Some controllers and wireless receivers instead appear, disappear, reconnect, or change USB identity as their state changes. Enabling wake on the relevant USB paths allows the USB hardware and Linux kernel to use those changes as wake sources.

## Wake behavior and limitations

The service runs once when installed and once during each boot. It does not continuously monitor controller input or decide whether a USB state change represents a device powering on or powering off. After the wake controls are enabled, wake handling is performed by the USB hardware and Linux kernel.

Wake authorization is not directional. Depending on the device, receiver, and USB topology, connection, disconnection, re-enumeration, or USB ID changes may wake the system.

For example, an 8BitDo Ultimate 2C receiver was observed changing its USB-visible state when the controller powered on or off. This allowed controller power-on to wake the system, but controller shutdown or automatic timeout could also wake it. Wireless mouse and keyboard receivers may behave differently because many remain connected to the USB bus when the peripheral itself is powered off.

-----

## Works with

The following is a small subset of tested controllers and devices.

It is worth mentioning that this service does not work on pure built in BT receivers (like combo wifi/bt cards).

A USB of some kind must be triggered, such as a dock or dongle.


| Device                | Model      | Connection Type           | Wake On             |
|-----------------------|------------|---------------------------|---------------------|
| 8BitDo Controller     | Ultimate 2 | Dongle & Base             | Controller Wake     |
| Xbox One Controller   | 1708       | Cable                     | Unplug & Plug event |
| Logitech KB/M Combo   | K400 Plus  | Included 2.4ghz Dongle    | Button Press        |


-----

## How to install

- Switch SteamOS to Desktop mode.
- Download the script from releases or copy it.

Now you must make the script executable:

```bash
chmod a+x usb-wake.sh
```

> [!TIP]
> **A sudo password must be set and it is not by default!**

SteamOS does not ship with a root password, so one must be set before you can execute things with ```sudo``` set one temporarily and then remove it again like so.

> [!NOTE]
> *It is assumed that you are using the default SteamOS user "deck", if not change command accordingly.*

First set the password for the account, make this something memorable or copy and paste the following.

```bash
yes "USBWake!" | passwd deck
```

Now simply navigate to the folder the script belongs to and execute it.

```bash
sudo ./usb-wake.sh
```

The script will output its status as it completes.

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/install.png?raw=true)

After the script runs and installs the service you remove the password using the following:

```bash
echo "USBWake!" | sudo -S -k passwd -d deck
```

Once the service install is complete you can test it by setting your sleep timeout in settings to a low number then turning off your controller.
After the machine goes to sleep simply wake the controller.

-----

## Features

- Installs a service that runs once during each boot and enables currently exposed USB devices and hubs with writable ```power/wakeup``` controls
- Automatically backs up the currently exposed USB wake settings during installation for restoration later
- Includes restoration feature to restore backups
- Includes uninstall feature to remove the service

-----

## Utility

The script itself has several flags to choose from including simply running it.

Use ```--help``` to open the menu.

```bash
Usage:
  ./usb-wake.sh
  ./usb-wake.sh --restore
  ./usb-wake.sh --uninstall
```

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/help.png?raw=true)


Additionally; user inputs are safeguarded for mistypes, preventing accidental usage.

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/invalid.png?raw=true)

## Restoring

Using the ```--restore``` flag allows you to temporarily restore USB wake settings from a backup. If the USB topology has changed since the backup was created, entries whose sysfs paths are no longer present or writable are skipped.

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/restore.png?raw=true)

## Uninstalling

Using the ```--uninstall``` flag allows you to remove the service and optionally restore from a configuration backup.

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/uninstall.png?raw=true)

