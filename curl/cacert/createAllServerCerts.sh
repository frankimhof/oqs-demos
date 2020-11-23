if [ $# -eq 0 ]
  then
    echo param1 \<NAME OF SERVER\> is missing. Use as follows:
    echo ./createAllServerCerts.sh \<NAME OF SERVER\>
    exit
fi

for SIG in ecdsap256 \
  dilithium2 \
  dilithium3 \
  p256_dilithium2 \
  p256_dilithium3 \
  dilithium4 \
  falcon512 \
  falcon1024 \
  rainbowIaclassic \
  rainbowVcclassic
do
  ./createServerCertSignedByCA.sh $SIG $1
done
