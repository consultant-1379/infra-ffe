#/bin/bash
scriptname=$(basename $0)
ssl_config=/etc/nginx/proxy_ssl_config
ssl_cert=/etc/nginx/proxycer.pem
ssl_key=/etc/nginx/proxykey.pem


create_ssl_cert(){
    output=$(openssl req -new -x509  -config ${ssl_config} -out ${ssl_cert} -keyout ${ssl_key} -days 365 -noenc 2>&1)
    if [ $? -eq 0 ]; then
        echo "${scriptname} Nginx SSL cert created successfully"
    else
        echo "${scriptname} - Failed to create NGINX SSL cert. Exited with code $?. Output $output"
    fi
}


if [ ! -f ${ssl_cert} ]; then
    echo "${scriptname} Nginx SSL cert doesn't exist. Creating it now ..."
    create_ssl_cert
else
    start=$(date -d "$(openssl x509 -noout -startdate -in ${ssl_cert} | cut -d= -f2)" +%s)
    end=$(date -d "$(openssl x509 -noout -enddate -in ${ssl_cert} | cut -d= -f2)" +%s)
    now=$(date +%s)
    if [ $now -le $start -o $now -ge $end ]; then
        echo "${scriptname} Nginx SSL cert doesn't exist. Creating a new cert now ..."
        create_ssl_cert
    else
        echo "${scriptname} Nginx SSL cert exists and is valid from $(date -d @$start -Iseconds) to $(date -d @$start -Iseconds)"
        exit 0
    fi
fi
