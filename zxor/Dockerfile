# 拉取基础镜像(统一使用内部基础镜像)
FROM intranet-harbor.laiyouxi.com/base/alpine/openresty:1.21.4.2 as builder

# 添加部分元数据，暂无意义
LABEL vendor="Lyx-yunwei"

# 维护者
#MAINTAINER name email

# 工作目录(统一使用/app目录)
WORKDIR /app

# 拷贝代码到工作目录(代码在宿主机上的当前目录)
COPY . /app/

RUN chmod +x /app/zxor/start_in_docker.sh

CMD [ "/bin/sh", "/app/zxor/start_in_docker.sh" ]