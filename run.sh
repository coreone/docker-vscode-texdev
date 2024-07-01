#!/usr/bin/env bash

declare -g CHKSUM_APP
declare -g CONTAINER_APP
declare -g CONTAINER_IMAGE
declare -g DOCKER_SOCKET
declare -ga GCLOUD_MOUNT
declare -g LABEL_PREFIX
declare -g SCRIPT_DIR
declare -ga SUDO
declare -ga TRACK_FILES
declare -ga TTY

CONTAINER_IMAGE='vscode-texdev:dev'
DOCKER_SOCKET='/var/run/docker.sock'
LABEL_PREFIX='org.broadinstitute.vscode-texdev'
SCRIPT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TRACK_FILES=( Dockerfile poetry.lock pyproject.toml )

if hash sha256sum 2>/dev/null; then
    CHKSUM_APP='sha256sum'
elif hash shasum 2>/dev/null; then
    CHKSUM_APP='shasum -a 256'
elif hash md5sum 2>/dev/null; then
    CHKSUM_APP='md5sum'
else
    echo 'Could not find a checksumming program. Exiting!'
    exit 1
fi

if hash docker 2>/dev/null; then
    CONTAINER_APP='docker'
elif hash podman 2>/dev/null; then
    CONTAINER_APP='podman'
else
    echo 'Container environment cannot be found. Exiting!'
    exit 2
fi

if [[ "$TERM" != 'dumb' ]]; then
    TTY=( -it )
fi

if [[ "$( uname -s )" != 'Darwin' ]]; then
    if [[ ! -w "$DOCKER_SOCKET" ]]; then
        SUDO=( sudo )
    fi
fi

if [ -d "${HOME}/.config/gcloud" ]; then
    GCLOUD_MOUNT=( -v "${HOME}/.config/gcloud:/root/.config/gcloud" )
fi

function build_check() {
    local rebuild
    local tfile
    local stored

    if ! "${SUDO[@]}" "$CONTAINER_APP" image ls | awk '{print $1":"$2}' | grep --quiet -E "^(localhost\/)*${CONTAINER_IMAGE}"; then
        rebuild='1'
    else
        rebuild='0'
        for tfile in "${TRACK_FILES[@]}"; do
            current="$( $CHKSUM_APP "$tfile" | cut -d' ' -f1 )"
            stored="$( $CONTAINER_APP image inspect --format="{{index .Config.Labels \"${LABEL_PREFIX}.${tfile}\"}}" "$CONTAINER_IMAGE" )"

            if [[ "$current" != "$stored" ]]; then
                echo "$tfile changed.  Rebuilding."
                rebuild='1'
            fi
        done
    fi

    if [[ "$rebuild" == '1' ]]; then
        build "$CONTAINER_IMAGE"
    fi
}

function build() {
    local label
    local -a labels
    local tfile

    if [[ -z "$1" ]]; then
        echo 'Image name not provided to build. Exiting!'
        exit 1
    fi
    CONTAINER_IMAGE=$1

    if [[ $(git diff --stat) != '' ]]; then
        echo 'Branch is dirty.  The build can only happen on an unmodified branch.'
        exit 2
    fi

    for tfile in "${TRACK_FILES[@]}"; do
        label="$( $CHKSUM_APP "$tfile" | awk -v PREFIX="$LABEL_PREFIX" '{print PREFIX"."$2"="$1}' )"
        labels+=( "--label=${label}" )
    done

    "${SUDO[@]}" "$CONTAINER_APP" build --pull -t "$CONTAINER_IMAGE" "${labels[@]}" .
}

pushd "$SCRIPT_DIR" >/dev/null || exit 1

# Test if a build is needed and, if so, kick one off
build_check

if [[ -d "${HOME}/.config/gcloud" ]]; then
    GCLOUD_MOUNT=( -v "${HOME}/.config/gcloud:/root/.config/gcloud" )
fi

"${SUDO[@]}" "$CONTAINER_APP" run "${TTY[@]}" --rm \
    "${GCLOUD_MOUNT[@]}" -v "${SCRIPT_DIR}:/working" \
    "$CONTAINER_IMAGE" "$@"

popd >/dev/null || exit 1
