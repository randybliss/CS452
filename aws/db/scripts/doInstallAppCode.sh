#!/bin/bash
usage() {
  echo "# Check for proper number of command line args.
# Arguments accepted:
#     --target - optional - specifies the absolute fully qualified path where tfApp code will be stored - default: /opt/tf
#"
}
E_BADARGS=65
TARGET="/opt/tf"

# Parse command line parameters
while [[ $# -ge 1 ]]
do
key="$1"
shift

case $key in
    --target)
    TARGET="$1"
    shift
    ;;
    *)
    echo "unknown argument type $key - exiting"
    usage
    exit $E_BADARGS
    ;;
esac
done

if [ -z "$TARGET" ]; then
  echo "Must specify jars path"
  usage
  exit $E_BADARGS
else
  echo Using jars path: $TARGET
fi

cd /home/fs
if [ -f tf-app.tar.gz ]; then
  tar xzvf tf-app.tar.gz
else
  echo "FATAL ERROR - TF App tarball must be present in /home/fs - terminating"
  exit 1
fi
sudo rm -rf $TARGET >/dev/null 2>&1
sudo mkdir -p $TARGET
sudo chown -R fs:fs $TARGET
sudo cp /home/fs/deploy/scripts/* /usr/local/bin
rm -rf /home/fs/deploy/scripts >/dev/null 2>&1
sudo mv /home/fs/deploy/* $TARGET
#cp ./deploy/*.jar $TARGET
#cp ./deploy/*.yml $TARGET
#cp ./deploy/keystore.jks $TARGET
sudo chown -R fs:fs /usr/local/bin
rm -rf /home/fs/deploy
exit 0
