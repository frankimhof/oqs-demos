### CACERTS
Contains all the CA.crt and CA.key files used in the experiment.
The server (named testserver) will listen on different ports and on each port a different SIG will be used.
For each SIG the server needs to create it's key and certificate and let it sign by the (SIG-specific) CA.
This can be done using the createServerCertSignedByCA.sh
```
SIG=dilithium2
SERVER_COMMON_NAME=testserver
createServerCertSignedByCA.sh ${SIG} ${SERVER_COMMON_NAME} 
```
