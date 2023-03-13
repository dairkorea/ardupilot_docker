FROM ubuntu:20.04
WORKDIR /ardupilot

ARG DEBIAN_FRONTEND=noninteractive
ARG USER_NAME=ardupilot
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd ${USER_NAME} --gid ${USER_GID}\
    && useradd -l -m ${USER_NAME} -u ${USER_UID} -g ${USER_GID} -s /bin/bash

RUN apt update --no-install-recommends \
    && apt upgrade --no-install-recommends -y \
    && apt-get install --no-install-recommends -y \
    build-essential \
    git \
    ca-certificates \
    lsb-release \
    sudo \
    tzdata \
    bash-completion \    
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel

RUN pip3 install pymavlink \
    && pip3 install mavproxy

#COPY Tools/environment_install/install-prereqs-ubuntu.sh /ardupilot/Tools/environment_install/
#COPY Tools/completion /ardupilot/Tools/completion/

# Create non root user for pip
ENV USER=${USER_NAME}

RUN echo "ardupilot ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME}
RUN chmod 0440 /etc/sudoers.d/${USER_NAME}

RUN chown -R ${USER_NAME}:${USER_NAME} /ardupilot

USER ${USER_NAME}

RUN mkdir -p /ardupilot && sudo chmod -R 777 /ardupilot

WORKDIR /ardupilot

RUN git config --global http.postBuffer 1048576000
RUN git clone https://github.com/ArduPilot/ardupilot .
RUN git checkout Copter-4.3.4 -b bijung/Copter-4.3.4
RUN git submodule update --init --recursive

WORKDIR /ardupilot

ENV SKIP_AP_EXT_ENV=1 SKIP_AP_GRAPHIC_ENV=1 SKIP_AP_COV_ENV=1 SKIP_AP_GIT_CHECK=1
RUN Tools/environment_install/install-prereqs-ubuntu.sh -y

ENV PATH=$PATH:/ardupilot/Tools/autotest
ENV PATH=/usr/lib/ccache:$PATH

# add waf alias to ardupilot waf to .bashrc
RUN echo "alias waf=\"/${USER_NAME}/waf\"" >> ~/ardupilot_entrypoint.sh

# Check that local/bin are in PATH for pip --user installed package
RUN echo "if [ -d \"\$HOME/.local/bin\" ] ; then\nPATH=\"\$HOME/.local/bin:\$PATH\"\nfi" >> ~/ardupilot_entrypoint.sh

# Create entrypoint as docker cannot do shell substitution correctly
RUN export ARDUPILOT_ENTRYPOINT="/home/${USER_NAME}/ardupilot_entrypoint.sh" \
    && echo "#!/bin/bash" > $ARDUPILOT_ENTRYPOINT \
    && echo "set -e" >> $ARDUPILOT_ENTRYPOINT \
    && echo "source /home/${USER_NAME}/.ardupilot_env" >> $ARDUPILOT_ENTRYPOINT \
    && echo 'exec "$@"' >> $ARDUPILOT_ENTRYPOINT \
    && chmod +x $ARDUPILOT_ENTRYPOINT \
    && sudo mv $ARDUPILOT_ENTRYPOINT /ardupilot_entrypoint.sh

# Set the buildlogs directory into /tmp as other directory aren't accessible
ENV BUILDLOGS=/tmp/buildlogs

WORKDIR /ardupilot/ArduCopter
RUN sim_vehicle.py -j4 -w

# Cleanup
RUN sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV CCACHE_MAXSIZE=1G
ENTRYPOINT ["/ardupilot_entrypoint.sh"]
CMD ["bash"]
