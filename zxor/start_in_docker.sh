#/bin/sh

luajit /app/zxor/zxor init /app -cp /usr/local/openresty/nginx/conf -cf nginx.conf -ll error -docker
exec openresty -g "daemon off;"