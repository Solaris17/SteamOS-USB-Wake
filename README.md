<h1 align="center">SteamOS USB Wake</h1>

> [!NOTE]
> *This tool and its author are not affiliated with Valve in any way.*

> [!TIP]
> **Please do not request install help in this repo!**

## About

This script installs and activates a service that allows USB devices on any USB root hub to wake SteamOS from sleep.

[SteamOS](https://help.steampowered.com/en/faqs/view/65B4-2AA3-5F37-4227) is installed on many DIY PCs by enthusiasts to make faux steam machines.

However; given the Steam Machine and Steam Decks nature, and OSs in general, these DIY PCs cannot be woken by most controllers.

To get around this, this service detects changes on the USB root hubs (USB device controllers) and if a change is detected (like a controller waking up (state change), or randomly appearing on the bus (bluetooth)) it triggers the wake command in the OS (like you pushed the power button.).

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

- Installs service that runs once each boot enabling currently connected usb hubs to wake the system
- Automatically backs up the current USB hub configuration for restoration later
- Includes restoration feature to restore backups
- Includes uninstall feature to remove the service

-----

## Utility

The script itself has several flags to choose from including simply running it.

Use ```--help``` to open the menu.

```bash
Usage:
  /home/tech/Downloads/usb-wake.sh
  /home/tech/Downloads/usb-wake.sh --restore
  /home/tech/Downloads/usb-wake.sh --uninstall
```

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/help.png?raw=true)


Additionally; user inputs are safeguarded for mistypes, preventing accidental usage.

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/invalid.png?raw=true)

## Restoring

Using the ```--restore``` flag allows you to temporarily restore USB hub settings from an automatic backup.

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/restore.png?raw=true)

## Uninstalling

Using the ```--uninstall``` flag allows you to remove the service and optionally restore from a configuration backup.

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/uninstall.png?raw=true)

