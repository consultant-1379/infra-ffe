# Build
docker build --file Dockerfile.base . -t hwsim-base:0.0.1
docker build --file Dockerfile.app . -t hwsim-app:0.0.1

# Install/Run
gzip -dc hwsim-app:0.0.1.gz | docker image load

mkdir /hwsim ; cd /hwsim
mkdir log etc var

cp <path/to/clouds.yml> etc/clouds.yml
openssl req -new -x509 -keyout /hwsim/etc/localhost.pem -out /hwsim/etc/localhost.pem -days 365 -nodes

docker run \
 -d \
 --volume /hwsim/etc:/hwsim/etc \
 --volume /var/edp/vol1/MASTER_siteEngineering.txt:/hwsim/etc/MASTER_siteEngineering.txt:ro \
 --volume /hwsim/log/:/hwsim/log/ \
 --volume /hwsim/var/:/hwsim/var/ \
 --network host \
 hwsim-app:0.0.1 ${DEPLOYMENT_NAME}

