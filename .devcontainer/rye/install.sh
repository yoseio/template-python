#!/usr/bin/env bash

RYE_VERSION="${VERSION:-"latest"}"
ENABLE_COMPLETION="${ENABLECOMPLETION:-"true"}"
ENABLE_UV="${ENABLEUV:-"true"}"

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"


# ------------------------------------------------------------------------------
#   https://github.com/devcontainers/features/blob/07dc0288d4b98f0ef76ea307d262ddc3d08b81c2/src/python/install.sh#L38-L43
# ------------------------------------------------------------------------------

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi


# ------------------------------------------------------------------------------
#   https://github.com/devcontainers/features/blob/07dc0288d4b98f0ef76ea307d262ddc3d08b81c2/src/python/install.sh#L571-L578
# ------------------------------------------------------------------------------

sudo_if() {
    COMMAND="$*"
    if [ "$(id -u)" -eq 0 ] && [ "$USERNAME" != "root" ]; then
        su - "$USERNAME" -c "$COMMAND"
    else
        $COMMAND
    fi
}


# ------------------------------------------------------------------------------
#   https://github.com/devcontainers/features/blob/07dc0288d4b98f0ef76ea307d262ddc3d08b81c2/src/python/install.sh#L659-L662
# ------------------------------------------------------------------------------

# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" > /etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh


# ------------------------------------------------------------------------------
#   https://github.com/devcontainers/features/blob/07dc0288d4b98f0ef76ea307d262ddc3d08b81c2/src/python/install.sh#L669-L684
# ------------------------------------------------------------------------------

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi


# ------------------------------------------------------------------------------
#   Install Rye
# ------------------------------------------------------------------------------

sudo_if "curl -sSf https://rye.astral.sh/get | RYE_VERSION=\"${RYE_VERSION}\" RYE_INSTALL_OPTION=\"--yes\" bash"

USERHOME="$(sudo_if printenv HOME)"
RYE_SRC="${RYE_HOME:-${USERHOME}/.rye}/shims/rye"

if [ "${ENABLE_COMPLETION}" = "true" ]; then
    sudo_if mkdir -p "${USERHOME}/.local/share/bash-completion/completions"
    sudo_if "\"${RYE_SRC}\" self completion > \"${USERHOME}/.local/share/bash-completion/completions/rye.bash\""
fi

if [ "${ENABLE_UV}" = "true" ]; then
    sudo_if "${RYE_SRC}" config --set-bool behavior.use-uv=true
fi
