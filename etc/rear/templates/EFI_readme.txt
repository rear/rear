How to boot an IA64 with EFI shell?
==================================
The following procedure can be handy is the default menu entries
of the EFI BIOS do not work for some reason, e.g.

Loading.: Red Hat Enterprise Linux Server
Load of Red Hat Enterprise Linux Server failed: Not Found
Press any key to continue

After pressing any key the following menu will re-appear:

EFI Boot Manager ver 1.10 [14.62]  Firmware ver 1.32 [4642]

Please select a boot option

    Red Hat Enterprise Linux Server
    Debian GNU/Linux
    iLO Virtual Media
    Core LAN Gb A
    Core LAN Gb B
    EFI Shell [Built-in]
    Internal Bootable DVD
    Boot Option Maintenance Menu
    System Configuration


    Use ^ and v to change option(s). Use Enter to select an option

When you see above menu use the arrow keys to select "EFI Shell"

The system will do the following:

Loading.: EFI Shell [Built-in]
EFI Shell version 1.10 [14.62]
Device mapping table
  fs0  : Acpi(HWP0002,PNP0A03,0)/Pci(2|1)/Usb(0, 0)/CDROM(Entry0)
  fs1  : Acpi(HWP0002,PNP0A03,400)/Pci(1|0)/Sas(Addr500000E012E6E892,Lun0)/HD(Part1,Sig91DAE95E-CED8-48B8-A852-1A484150DD8C)
  fs2  : Acpi(HWP0002,PNP0A03,400)/Pci(1|0)/Sas(Addr500000E012E6ECB2,Lun0)/HD(Part1,Sig9B95F64C-840E-4D5E-A33F-1526ECDD4874)
  blk0 : Acpi(HWP0002,PNP0A03,0)/Pci(2|1)/Usb(0, 0)
  blk1 : Acpi(HWP0002,PNP0A03,0)/Pci(2|1)/Usb(0, 0)/CDROM(Entry0)
  blk2 : Acpi(HWP0002,PNP0A03,0)/Pci(2|1)/Usb(0, 0)/CDROM(Entry1)
  blk3 : Acpi(HWP0002,PNP0A03,400)/Pci(1|0)/Sas(Addr500000E012E6E892,Lun0)
  blk4 : Acpi(HWP0002,PNP0A03,400)/Pci(1|0)/Sas(Addr500000E012E6E892,Lun0)/HD(Part1,Sig91DAE95E-CED8-48B8-A852-1A484150DD8C)
  blk5 : Acpi(HWP0002,PNP0A03,400)/Pci(1|0)/Sas(Addr500000E012E6E892,Lun0)/HD(Part2,Sig3CBAF54B-9FC8-46AB-9F56-3132563FEA1A)
  blk6 : Acpi(HWP0002,PNP0A03,400)/Pci(1|0)/Sas(Addr500000E012E6E892,Lun0)/HD(Part3,SigBA950E2C-9568-4F1B-9D18-3EAB0E472AAA)
  blk7 : Acpi(HWP0002,PNP0A03,400)/Pci(1|0)/Sas(Addr500000E012E6ECB2,Lun0)
  blk8 : Acpi(HWP0002,PNP0A03,400)/Pci(1|0)/Sas(Addr500000E012E6ECB2,Lun0)/HD(Part1,Sig9B95F64C-840E-4D5E-A33F-1526ECDD4874)
  blk9 : Acpi(HWP0002,PNP0A03,400)/Pci(1|0)/Sas(Addr500000E012E6ECB2,Lun0)/HD(Part2,Sig098B63E6-6961-417E-8F23-7E809E0EF94D)

At the Shell> prompt select the disk you want, e.g.
Shell> fs2:

Just like with a DOS command prompt use cd and dir commands to view the FAT16
content:

fs2:\> cd efi
fs2:\EFI> dir
Directory of: fs2:\EFI

  06/28/07  10:09a <DIR>          2,048  .
  06/28/07  10:09a <DIR>              0  ..
  11/30/07  10:31a <DIR>          2,048  Intel Firmware
  11/30/07  10:37a <DIR>          2,048  redhat
  08/26/08  03:11p <DIR>          2,048  rear
  07/12/07  03:55p <DIR>          2,048  recovery
          0 File(s)           0 bytes
          6 Dir(s)


fs2:\EFI> cd redhat

To boot redhat just enter:

fs2:\EFI\redhat> elilo
ELILO boot: Uncompressing Linux... done
Loading file initrd...

Just let it boot 'till you get the login prompt.
Feedback on the above? Use 'rear validate' to mail us your comments.
