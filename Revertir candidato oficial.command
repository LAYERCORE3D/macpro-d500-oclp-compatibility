#!/bin/zsh
cd -- "${0:A:h}"
sudo /usr/bin/python3 "$PWD/install.py" --rollback
result=$?
if (( result == 0 )); then
 print "Proceso terminado. No se ha reiniciado el Mac."
else
 print "No completado. Conserva el mensaje anterior; no reinicies."
fi
read -k 1 "?Pulsa una tecla para cerrar..."
exit $result
