# Generates srv.crt and srv.key 
# params:
# 1: sig name
# 2: server common name

OPENSSL_PATH=/opt/openssl

if [ $# -eq 0 ]
  then
    echo both the SIG name and the common name of server must be specified, for example:
    echo ./createServerCertSignedByCA.sh dilithium2 myDili2server
    exit
fi
if [ $# -eq 1 ]
  then
    echo Common Name of Server \(param 2\) missing
    exit
fi

case "$1" in
  #check if SIG name valid
  "ecdsap256" | "dilithium2" | "dilithium3" | "dilithium4" | "p256_dilithium2" | "p256_dilithium3" | "p384_dilithium4" | "falcon512" | "falcon1024" | "rainbowIaclassic" | "rainbowVcclassic")
    # Check if SIG_CA.crt and SIG_CA.key exist
    if [ ! -f "$1_CA.key" ]; then
      echo $1_CA.key is missing
      exit
    fi
    if [ ! -f "$1_CA.key" ]; then
      echo $1_CA.key is missing
      exit
    fi
    if [ "$1" == "ecdsap256" ]; then
      $OPENSSL_PATH/apps/openssl req -new -newkey ec:<($OPENSSL_PATH/apps/openssl ecparam -name prime256v1) -keyout $1_srv.key -out $1_srv.csr -nodes -subj "/CN=${2}" -config $OPENSSL_PATH/apps/openssl.cnf
      else
      $OPENSSL_PATH/apps/openssl req -new -newkey $1 -keyout $1_srv.key -out $1_srv.csr -nodes -subj "/CN=${2}" -config $OPENSSL_PATH/apps/openssl.cnf
    fi
    $OPENSSL_PATH/apps/openssl x509 -req -in $1_srv.csr -out $1_srv.crt -CA $1_CA.crt -CAkey $1_CA.key -CAcreateserial -days 365
  ;;
  *) #if SIG name not valid
      echo SIG name must be one of the following:$'\n'ecdsap256$'\n'dilithium2$'\n'dilithium3$'\n'dilithium4$'\n'p256_dilithium2$'\n'p256_dilithium3$'\n'p348_dilithium4$'\n'falcon512$'\n'falcon1024$'\n'rainbowIaclassic$'\n'rainbowVcclassic
  ;;
esac
