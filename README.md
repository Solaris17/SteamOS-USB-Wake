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

Now simply navigate to the folder the script belongs to and execute it.

```bash
./usb-wake.sh
```

The script will output its status as it completes.

> [!TIP]
> If your SteamOS user has no admin password, the script can temporarily set one, run with sudo, then remove it automatically.
> Default temporary password: `USBWake!`
> You can override it: `USB_WAKE_TEMP_PASSWORD='YourTempPass' ./usb-wake.sh`

Once the service install is complete you can test it by setting your sleep timeout in settings to a low number then turning off your controller.
After the machine goes to sleep simply wake the controller.

-----

## Utility

During script execution the various stages will print out.

![alt text](https://github.com/Solaris17/SteamOS-USB-Wake/blob/main/pics/image.png?raw=true)


## Removal

If at any point you would like to uninstall the change, run the script and select `Uninstall` from the menu:

```bash
./usb-wake.sh
```

Or run uninstall directly:

```bash
./usb-wake.sh uninstall
```

> [!TIP]
> **If you get errors during file deletion.**

You likely have SteamOS readonlyFS enabled which is the default.

Simply disable it, then re-enable it once removal is complete.

```bash
sudo steamos-readonly disable
```

Then

```bash
sudo steamos-readonly enable
```
