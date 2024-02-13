# Pull the shellcheck image so we can fetch out the shellcheck binary
FROM docker.io/koalaman/shellcheck:latest as shellcheck

FROM docker.io/hashicorp/terraform:latest as terraform

FROM docker.io/library/python:3.11-slim

# This Dockerfile adds a non-root 'vscode' user with sudo access. However, for Linux,
# this user's GID/UID must match your local user UID/GID to avoid permission issues
# with bind mounts. Update USER_UID / USER_GID if yours is not 1000. See
# https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

COPY analytics.yml pyproject.toml poetry.lock README.md /tmp/

COPY --from=shellcheck /bin/shellcheck /bin/shellcheck
COPY --from=terraform /bin/terraform /bin/terraform

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -yq bind9utils curl dialog g++ gcc git \
        gnupg iproute2 libssl-dev libxml2-dev libffi-dev libxslt1-dev locales-all \
        lsb-release make openssh-client procps ruby ruby-dev sudo \
    && curl -o /tmp/puppetlabs.deb https://apt.puppet.com/puppet7-release-bullseye.deb \
    && dpkg -i /tmp/puppetlabs.deb \
    && apt-get update \
    && apt-get install -yq puppet-agent pdk \
    && pip install -U pip poetry \
    && gem install bundler rake --no-doc \
    && bundle config --global silence_root_warning 1 \
    && rm -f /etc/localtime \
    && ln -s /usr/share/zoneinfo/America/New_York /etc/localtime \
    && mkdir -p /root/.config/puppet \
    && cp /tmp/analytics.yml /root/.config/puppet/analytics.yml \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -d "/home/$USERNAME" -m -s /bin/bash -u $USER_UID -g $USER_GID $USERNAME \
    && mkdir -p /home/vscode/.config/puppet \
    && cp /tmp/analytics.yml /home/vscode/.config/puppet/analytics.yml \
    && chown -R ${USERNAME}:${USERNAME} /home/vscode/.[a-z]* \
    && cd /tmp \
    && poetry config virtualenvs.create false \
    && poetry install --no-ansi -v --no-root \
    && chmod 755 /bin/shellcheck \
    && rm -rf /root/.cache \
    && rm -rf /tmp/* \
    && rm -rf /var/cache/apt/* \
    && rm -rf /var/tmp/*
    # [Optional] Add sudo support for the non-root user
#    && apt-get install -y sudo \
#    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
#    && chmod 0440 /etc/sudoers.d/$USERNAME \
