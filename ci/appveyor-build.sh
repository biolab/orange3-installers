#!/usr/bin/env bash

set -e

_exit() {
    local status=${1:?}
    shift 1
    echo "$@" >&2
    exit ${status}
}

# echo and run the command
echo_run() {
    echo \$ "$@"
    "$@"
}

[[ ${PYTHON_VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo Invalid PYTHON_VERSION ${PYTHON_VERSION} >&2; exit 1;
}

if [[ ! ${PLATTAG} =~ ^(win32|win_amd64)$ ]]; then
    echo Invalid PLATTAG ${PLATTAGe} >&2; exit 1
fi

PYTAG=${PYTHON_VERSION:0:1}${PYTHON_VERSION:2:1}

SPECARGS=(
    --python-version ${PYTHON_VERSION}
    --platform ${PLATTAG}
    --pip-arg=-r --pip-arg=${ENVSPEC}
)

echo "PYTAG    = ${PYTAG}"
echo "SPECARGS = ${SPECARGS[@]}"

test -d orange3 || echo_run git clone -q --depth 20 ${REPO:?}
echo_run cd orange3

echo_run git fetch origin ${BUILD_BRANCH}
echo_run git checkout ${BUILD_COMMIT}
# Store/restore path around the build to not affect the tests later

PATH_BEFORE_BUILD=${PATH}
PYTHON_PREFIX=$(cygpath -u "${PYTHON:?}")
export PATH="${PYTHON_PREFIX}:${PYTHON_PREFIX}/Scripts:${PATH}"

# https://bugs.python.org/issue29943
python -c "import sys; assert not sys.version_info[:3] == (3, 6, 1)" || exit $?

echo_run python --version || exit 1
echo_run python -m pip --version  || exit 1

if [ ${BUILD_DEPS} ]; then
    echo_run python -m pip install ${BUILD_DEPS}
fi

echo_run python setup.py build ${BUILD_OPTIONS} bdist_wheel --dist-dir ../wheels

VERSION=$(python setup.py --version | grep ".")
echo "VERSION  =  ${VERSION}"

set PATH="/c/msys64/usr/bin:/c/Program Files (x86)/NSIS:${PATH}"

which unzip >/dev/null 2>&1 || echo_run pacman -S --noconfirm unzip || exit $?

echo_run which unzip || exit $?

echo_run ./scripts/windows/build-win-installer.sh --find-links=../wheels \
    --pip-arg=orange3==${VERSION} "${SPECARGS[@]}" || exit $?

INSTALLER=Orange3-${VERSION}-Python${PYTAG}-${PLATTAG}.exe

echo_run sha256sum -b dist/${INSTALLER}

# restore original path