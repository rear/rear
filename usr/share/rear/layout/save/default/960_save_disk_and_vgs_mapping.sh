# 960_save_disk_and_vgs_mapping.sh
# We run this as last script in the savelayout workflow as we want to compare the
# latest created /var/lib/rear/layout/disklayout.conf with pvs output and save
# the combined output in /var/lib/rear/recovery/device-mapping-of-[hostname]
# We could use this file in case we need manually intervention with disk mapping
# as the disk device sizes are the key for proper mapping with the new disk layout.
#
# Example output file:
# disk /dev/sdo 21474836480 unknown      /dev/sdo   vg00        lvm2 a--    <20.00g       0
# disk /dev/sdb 48318382080 msdos        /dev/sdb2  vg00        lvm2 a--    <44.50g       0
# disk /dev/sdp 5368709120 unknown       /dev/sdp   vg00        lvm2 a--     <5.00g    2.25g
# disk /dev/sdn 16106127360 unknown      /dev/sdn   vg-dvl      lvm2 a--    <15.00g   <5.00g
# disk /dev/sdh 5368709120 unknown       /dev/sdh   vg_oem      lvm2 a--     <5.00g       0
# disk /dev/sdc 107374182400 unknown     /dev/sdc   vg_oraarch  lvm2 a--   <100.00g       0
# disk /dev/sda 59055800320 unknown      /dev/sda   vg_oracle   lvm2 a--    <55.00g       0
# disk /dev/sdd 1073741824000 unknown    /dev/sdd   vg_oradata  lvm2 a--  <1000.00g       0
# disk /dev/sdl 536870912000 unknown     /dev/sdl   vg_oradata  lvm2 a--   <500.00g       0
# disk /dev/sdm 590558003200 unknown     /dev/sdm   vg_oradata  lvm2 a--   <550.00g   48.99g
# disk /dev/sdf 10737418240 unknown      /dev/sdf   vg_oraredo1 lvm2 a--    <10.00g       0
# disk /dev/sdg 10737418240 unknown      /dev/sdg   vg_oraredo2 lvm2 a--    <10.00g       0
# disk /dev/sdi 536870912000 unknown     /dev/sdi   vg_recovery lvm2 a--   <500.00g       0
# disk /dev/sdj 536870912000 unknown     /dev/sdj   vg_recovery lvm2 a--   <500.00g       0
# disk /dev/sdk 536870912000 unknown     /dev/sdk   vg_recovery lvm2 a--   <500.00g 1012.00m
# disk /dev/sde 17179869184 unknown      /dev/sde   vg_swap     lvm2 a--    <16.00g   <3.00g

# The output is not crucial for recovery, but it may come handy in case you are lost which
# disk belonged to which Volume Group. As you may know disk names can be different in a DR
# situation and then the only way to be sure is the "size" of the disk. 

paste <( grep ^disk /var/lib/rear/layout/disklayout.conf) <(pvs 2>/dev/null | grep '/dev/') | \
 column -s $'\t' -t | sort -k6 > /var/lib/rear/recovery/device-mapping-of-$(hostname -s)

Log "Saved disk device mapping towards VGs into /var/lib/rear/recovery/device-mapping-of-$(hostname -s)"
