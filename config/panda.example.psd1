@{
    Image = 'windows11-panda-lab:1.8.83'
    Container = 'windows11-panda'

    # Directory containing the licensed source disk.
    VmRoot = 'D:\VMs\Windows11'
    BaseDisk = 'Windows11.vdi'

    # All generated disks, firmware copies, keys, recordings, and logs.
    WorkRoot = 'D:\VMs\Windows11\panda'

    # Generated paths may use subdirectories, but must remain under WorkRoot.
    PrepOverlay = 'qemu\Windows11-panda-prep.qcow2'
    PrepVars = 'qemu\Windows11-prep-vars.fd'
    SeedDisk = 'Windows11-panda-seed.qcow2'
    ActiveDisk = 'Windows11-panda-active.qcow2'
    PandaCode = 'Windows11-panda-code.fd'
    PandaVars = 'Windows11-panda-vars.fd'

    QemuSystem = 'C:\Program Files\qemu\qemu-system-x86_64w.exe'
    QemuImg = 'C:\Program Files\qemu\qemu-img.exe'
    HostOvmfCode = 'C:\Program Files\qemu\share\edk2-x86_64-code.fd'
    HostOvmfVars = 'C:\Program Files\qemu\share\edk2-i386-vars.fd'

    MonitorPort = 4444
    NoVncPort = 6080
    SshPort = 2222
    QmpPort = 5955
}
