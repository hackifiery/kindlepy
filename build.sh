#!/bin/sh
set -e

### CONFIG ############################################################

SYSROOT=~/x-tools/arm-kindlepw3-linux-musleabi/arm-kindlepw3-linux-musleabi/sysroot
HOST=arm-kindlepw3-linux-musleabi
BUILD=x86_64-linux-gnu
PREFIX=/usr
OUTDIR=kindle-python

export CC=${HOST}-gcc
export AR=${HOST}-ar
export RANLIB=${HOST}-ranlib
export STRIP=${HOST}-strip

########################################################################

echo "[*] Cleaning previous build"
make distclean || true
rm -f config.cache

echo "[*] Writing config.site"
cat > config.site <<'EOF'
ac_cv_file__dev_ptmx=yes
ac_cv_file__dev_ptc=no
ac_cv_func_fork=yes
ac_cv_func_vfork=yes
ac_cv_func_execv=yes
EOF

export CONFIG_SITE=$PWD/config.site

echo "[*] Writing Modules/Setup.local"
cat > Modules/Setup.local <<'EOF'
*static*
*disabled*
_asyncio
_ssl
_hashlib
_uuid
_sqlite3
_ctypes
_readline
_tkinter
_dbm
_gdbm
_nis
_lzma
_zlib
_binascii
_zstd
ossaudiodev
zlib
binascii
lzma
zstd
readline
EOF

echo "[*] Configuring Python 3.14"
./configure \
  --host=${HOST} \
  --build=${BUILD} \
  --prefix=${PREFIX} \
  --enable-shared \
  --disable-static \
  --without-ensurepip \
  --disable-test-modules \
  --with-build-python=python3 \
  --disable-ipv6 \
  CFLAGS="--sysroot=${SYSROOT} -Os -fPIC -march=armv7-a -mfloat-abi=softfp" \
  LDFLAGS="--sysroot=${SYSROOT}"

echo "[*] Building"
make -j$(nproc) HOSTPYTHON=python3

echo "[*] Staging install"
rm -rf stage
make DESTDIR=$PWD/stage install

echo "[*] Assembling output directory"
rm -rf ${OUTDIR}
mkdir -p ${OUTDIR}
mv stage/usr/* ${OUTDIR}/

echo "[*] Copying musl runtime"
cp -f ${SYSROOT}/lib/ld-musl-arm.so.1 ${OUTDIR}/lib/
cp -f ${SYSROOT}/usr/lib/libc.so ${OUTDIR}/lib/

echo "[*] Patching ELF interpreter and rpath"
patchelf \
  --set-interpreter /mnt/us/python/lib/ld-musl-arm.so.1 \
  ${OUTDIR}/bin/python3.14

patchelf \
  --set-rpath '$ORIGIN/../lib' \
  ${OUTDIR}/bin/python3.14

patchelf \
  --set-rpath '$ORIGIN' \
  ${OUTDIR}/lib/libpython3.14.so*

echo "[*] Stripping binaries"
${STRIP} \
  ${OUTDIR}/bin/python3.14 \
  ${OUTDIR}/lib/libpython3.14.so*

echo "[*] Patching scripts"
patch --strip=0 < kindle.patch
rm kindle-python/bin/idle3.14

echo "[✓] Build complete: ${OUTDIR}"

