#!/bin/bash

set -e
set -u

OUTDIR_DEFAULT=/tmp/aeld
OUTDIR="${OUTDIR_DEFAULT}"
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$(realpath "$1")
    echo "Using passed directory ${OUTDIR} for output"
fi

if [ ! -d "${OUTDIR}" ]; then
    echo "Creating output directory ${OUTDIR}"
    mkdir -p "${OUTDIR}" || { echo "Failed to create ${OUTDIR}"; exit 1; }
fi

OUTDIR=$(realpath "${OUTDIR}")

cd "${OUTDIR}"

if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION} linux-stable
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION} || true

    echo "Starting kernel build for ${ARCH}"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} Image
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs || true
    cd "${OUTDIR}"
fi

echo "Adding the Image in outdir"
cp -a ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/Image

cd "${OUTDIR}"
if [ -d "${OUTDIR}/rootfs" ]
then
    echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

mkdir -p ${OUTDIR}/rootfs/{bin,sbin,etc,proc,sys,usr/bin,usr/sbin,usr/lib,usr/lib64,lib,lib64,dev,home,root,tmp,mnt}

cd "${OUTDIR}"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone https://github.com/mirror/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
else
    cd busybox
fi

make distclean || true
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

if [ ! -e ${OUTDIR}/rootfs/bin/busybox ]; then
    echo "Busybox installation failed"; exit 1
fi

SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot 2>/dev/null || true)
if [ -n "${SYSROOT}" ]; then
    echo "Using sysroot: ${SYSROOT}"
    cp -a ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/ 2>/dev/null || true
    cp -a ${SYSROOT}/lib64/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib64/ 2>/dev/null || true
    cp -a ${SYSROOT}/lib64/libm.so.* ${OUTDIR}/rootfs/lib64/ 2>/dev/null || true
    cp -a ${SYSROOT}/lib64/libresolv.so.* ${OUTDIR}/rootfs/lib64/ 2>/dev/null || true
    cp -a ${SYSROOT}/lib64/libc.so.* ${OUTDIR}/rootfs/lib64/ 2>/dev/null || true
fi

sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3 || true
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1 || true

echo "Building writer utility using provided Makefile"
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}
cp writer ${OUTDIR}/rootfs/home/
make clean

# Create necessary directories
mkdir -p ${OUTDIR}/rootfs/home/conf

# Copy finder scripts and configs
cp ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/ || true
cp ${FINDER_APP_DIR}/conf/username.txt ${OUTDIR}/rootfs/home/conf/ || true
cp ${FINDER_APP_DIR}/conf/assignment.txt ${OUTDIR}/rootfs/home/conf/ || true

# Update finder-test.sh to reference conf/assignment.txt
sed 's#../conf/assignment.txt#conf/assignment.txt#g' ${FINDER_APP_DIR}/finder-test.sh > ${OUTDIR}/rootfs/home/finder-test.sh || true

# Copy autorun-qemu.sh if it exists
if [ -f ${FINDER_APP_DIR}/autorun-qemu.sh ]; then
    cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/
fi

# Make scripts executable
chmod +x ${OUTDIR}/rootfs/home/finder.sh
chmod +x ${OUTDIR}/rootfs/home/finder-test.sh
chmod +x ${OUTDIR}/rootfs/home/autorun-qemu.sh || true

# Create init script for initramfs
cat > ${OUTDIR}/rootfs/init << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
echo "Starting BusyBox init"
cd /home
if [ -x ./finder-test.sh ]; then
    ./finder-test.sh
fi
/bin/sh
EOF

chmod +x ${OUTDIR}/rootfs/init

# Ensure root ownership
sudo chown -R root:root ${OUTDIR}/rootfs || true

# Build initramfs
cd ${OUTDIR}/rootfs
find . | cpio -o -H newc > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio

# Done
echo "initramfs created at ${OUTDIR}/initramfs.cpio.gz"
echo "All done. Kernel Image: ${OUTDIR}/Image  Initramfs: ${OUTDIR}/initramfs.cpio.gz"
echo "To boot in QEMU:"
echo "qemu-system-aarch64 -M virt -cpu cortex-a53 -m 1024 -nographic -kernel ${OUTDIR}/Image -initrd ${OUTDIR}/initramfs.cpio.gz -append \"console=ttyAMA0\""
