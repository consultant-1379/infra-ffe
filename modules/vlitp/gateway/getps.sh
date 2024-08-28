#!/bin/bash

PS=$1

SW_DIR=/var/edp/vol1/$PS
if [ ! -d ${SW_DIR} ] ; then
    mkdir -p ${SW_DIR}
fi

for DIR in LITP RHEL ENM EDP NAS ; do
    if [ ! -d ${SW_DIR}/${DIR} ] ; then
        mkdir ${SW_DIR}/${DIR}
    fi
done

cd ${SW_DIR}/ENM
wget -q -O releasenote.json "https://ci-portal.seli.wh.rnd.internal.ericsson.com/api/getReleaseNote/ENM/${PS}/?format=json"

ENM=$(cat releasenote.json | grep ERICenm_CXP9027091 | sed -e 's/.*ERICenm_CXP9027091-//' -e 's/.iso.*//')
EDP=$(cat releasenote.json | grep ERICautodeploy_CXP9038326 | sed -e 's/.*ERICautodeploy_CXP9038326-//' -e 's/.tar.gz.*//')
LITP=$(cat releasenote.json | grep  ERIClitp_CXP9024296 | sed -e 's/.*ERIClitp_CXP9024296-//' -e 's/.iso.*//')
RHEL_PS=$(cat releasenote.json | grep  RHEL79_OS_Patch_Set_CXP9041797 | sed -e 's/.*RHEL79_OS_Patch_Set_CXP9041797-//' -e 's/.iso.*//')
RHEL_MED=$(cat releasenote.json | grep RHEL79-MEDIA_CXP9041796 | sed -e 's/.*RHEL79-MEDIA_CXP9041796-//' -e 's/.iso.*//')
RHEL8_PS=$(cat releasenote.json | grep RHEL88_OS_Patch_Set_CXP9043482 | sed -e 's/.*RHEL88_OS_Patch_Set_CXP9043482-//' -e 's/.iso.*//')
RHEL8_MED=$(cat releasenote.json | grep RHEL88-MEDIA_CXP9043481 | sed -e 's/.*RHEL88-MEDIA_CXP9043481-//' -e 's/.iso.*//')
NAS_PS=$(cat releasenote.json | grep nas-rhel79-os-patch-set_CXP9042008 | sed -e 's/.*nas-rhel79-os-patch-set_CXP9042008-//' -e 's/.tar.gz.*//')
NAS_CONFIG=$(cat releasenote.json | grep ERICnasconfig_CXP9033343 | sed -e 's/.*ERICnasconfig_CXP9033343-//' -e 's/.tar.gz.*//')

getItem() {
    DIR=$1
    LINK=$2

    cd ${DIR}
    FILE=$(basename ${LINK})
    if [ ! -r ${FILE} ] ; then
        wget -q ${LINK}
    fi
}

getItem ${SW_DIR}/ENM https://arm901-eiffel004.athtem.eei.ericsson.se:8443/nexus/content/groups/enm_deploy_proxy/com/ericsson/oss/ERICenm_CXP9027091/${ENM}/ERICenm_CXP9027091-${ENM}.iso &

getItem ${SW_DIR}/EDP https://arm901-eiffel004.athtem.eei.ericsson.se:8443/nexus/content/repositories/enm_releases/com/ericsson/oss/itpf/autodeploy/ERICautodeploy_CXP9038326/${EDP}/ERICautodeploy_CXP9038326-${EDP}.tar.gz &

getItem ${SW_DIR}/LITP https://arm901-eiffel004.athtem.eei.ericsson.se:8443/nexus/content/repositories/litp_releases/com/ericsson/nms/litp/ERIClitp_CXP9024296/${LITP}/ERIClitp_CXP9024296-${LITP}.iso &

# RHEL 7 Patches and Media
getItem ${SW_DIR}/RHEL https://arm901-eiffel004.athtem.eei.ericsson.se:8443/nexus/content/repositories/iso/com/ericsson/nms/litp/RHEL79_OS_Patch_Set_CXP9041797/${RHEL_PS}/RHEL79_OS_Patch_Set_CXP9041797-${RHEL_PS}.iso &
getItem ${SW_DIR}/RHEL https://arm901-eiffel004.athtem.eei.ericsson.se:8443/nexus/content/repositories/iso/com/ericsson/nms/litp/RHEL79-MEDIA_CXP9041796/${RHEL_MED}/RHEL79-MEDIA_CXP9041796-${RHEL_MED}.iso &

# RHEL 8 Patches and Media
getItem ${SW_DIR}/RHEL https://arm901-eiffel004.athtem.eei.ericsson.se:8443/nexus/content/repositories/iso/com/ericsson/nms/litp/RHEL88_OS_Patch_Set_CXP9043482/${RHEL8_PS}/RHEL88_OS_Patch_Set_CXP9043482-${RHEL8_PS}.iso &
getItem ${SW_DIR}/RHEL https://arm901-eiffel004.athtem.eei.ericsson.se:8443/nexus/content/repositories/iso/com/ericsson/nms/litp/RHEL88-MEDIA_CXP9043481/${RHEL8_MED}/RHEL88-MEDIA_CXP9043481-${RHEL8_MED}.iso &

getItem ${SW_DIR}/NAS https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus/content/repositories/nas-media/com/ericsson/oss/itpf/nas/nas-rhel79-os-patch-set_CXP9042008/${NAS_PS}/nas-rhel79-os-patch-set_CXP9042008-${NAS_PS}.tar.gz &
getItem ${SW_DIR}/NAS https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus/content/repositories/nas-media/com/ericsson/oss/itpf/nas/ERICnasconfig_CXP9033343/${NAS_CONFIG}/ERICnasconfig_CXP9033343-${NAS_CONFIG}.tar.gz &

wait
