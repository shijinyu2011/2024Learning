docker-compose.yml  Dockerfile0000406  Dockerfile24329  gitconfig      repo           requirements.txt.0226  requirements.txtbak
[root@s121 agent]# cat Dockerfile
# Ref:
# https://hub.docker.com/r/jenkins/agent/dockerfile
# https://hub.docker.com/r/jenkins/inbound-agent/dockerfile
# https://github.com/jenkinsci/docker-inbound-agent

#ARG BASEIMG=nvp/ubuntu
ARG BASEIMG=nvp/test
FROM ${BASEIMG}
MAINTAINER nvp-nds

USER root

RUN apt-get update
RUN apt-get -y install openjdk-11-jre jq

ARG VERSION=4.13.3
RUN curl --create-dirs -fsSLo /usr/share/jenkins/agent.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar &&\
  chmod 755 /usr/share/jenkins &&\
  chmod 644 /usr/share/jenkins/agent.jar &&\
  ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar

COPY jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
  ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave

ARG PYTHON=python3
ARG PY_MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple
#ARG PY_MIRROR=https://mirrors.aliyun.com/pypi/simple/

ARG APT_MIRROR=mirrors.163.com
ARG DEBIAN_FRONTED=noninteractive
#RUN find /etc/apt -type f -name "*.list" -exec sed -i s/deb.debian.org/$APT_MIRROR/ {} \;
#RUN find /etc/apt -type f -name "*.list" -exec sed -i s/security.debian.org/$APT_MIRROR/ {} \;
#RUN find /etc/apt -type f -name "*.list" -exec sed -i s/archive.ubuntu.com/$APT_MIRROR/ {} \;
#RUN find /etc/apt -type f -name "*.list" -exec sed -i s/security.ubuntu.com/$APT_MIRROR/ {} \;
RUN apt-get -y install python3.8 && ln -sf /usr/bin/python3.8 /usr/bin/python3
RUN apt-get -y install ${PYTHON}-pip
RUN $PYTHON -m pip install -i ${PY_MIRROR} --upgrade pip
RUN pip config set global.index-url ${PY_MIRROR}
#RUN pip install requests
COPY repo /usr/bin/repo
RUN apt-get -y install locales zip
RUN locale-gen en_US.UTF-8
RUN apt-get -y install gcc-multilib g++-multilib
RUN apt-get -y install net-tools
RUN apt-get -y install gawk
RUN apt-get -y install cron
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN pip install pyyaml
RUN apt-get -y install rsyslog
RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf
RUN sed -i 's/#cron\.\*/cron\.\*/' /etc/rsyslog.d/50-default.conf
RUN apt-get -y install python3.8-dev
RUN rm -rf /usr/local/lib/python3.6
RUN rm -rf /usr/local/lib/python3.7
COPY cleanup.sh /home/cleanup.sh
RUN chmod 777 /home/cleanup.sh
RUN echo "1 */4 * * * /home/cleanup.sh >> /tmp/cron.log 2>&1" >> /var/spool/cron/crontabs/root
RUN chmod 600 /var/spool/cron/crontabs/root

ARG USER=jenkins
ARG HOME=/home/$USER
USER $USER
WORKDIR $HOME
ENV USER=$USER
ARG USER=jenkins
ARG UID=1000
ARG HOME=/home/jenkins
#RUN useradd -d /home/jenkins -m -u 1000 jenkins
#RUN adduser jenkins sudo
#RUN echo "jenkins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
ENV USER=$USER
ENV DEPLOYER_CC=/nas/software/toolchain/gcc-5.5.0

USER jenkins
WORKDIR /home/jenkins

ENTRYPOINT ["jenkins-agent"]

[root@s121 agent]#
