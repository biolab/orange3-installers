#!/usr/bin/env bash

# exit on any error
set -e

function usage() {
    echo "build-conda-installer.sh

Build a conda based based windows application installer.

Note: This script needs makensis and curl on \$PATH
Note: Needs basic bash env on Windows (git-bash is sufficient/tested, but
      cygwin should work too)

Options:
    -b --build-base <path>  Build directory (default ./build)
    -d --dist-dir <path>    Distribution dir (default ./dist)
    --cache-dir <path>      Cache downloaded packages in DIR (the default
                            is \"build/download-cache\")
    -M, --micromamba-version <version>
                            The micromamba distribution to include in the
                            installer (default ${MICROMAMBA_VERSION_DEFAULT}).
    --platform <plattag>    win32 or win_amd64
    --env-spec              An environment specification file as exported by
                            \`conda list --export --explicit --md5\`
                            (the default is specs/conda-spec.txt)
    --online (yes|no)       Build an \"online\" or \"offline\" installer.
                            In an online installer only the micromamba binary
                            is included. All other packages are otherwise
                            fetched at installation time
                            (offline is currently not recommended).
    -h --help               Print this help


Examples

    $ ./scripts/windows/build-conda-installer.sh --online=yes
"
}

NAME=Orange3
# version is determined from the ENV_SPEC_FILE
VERSION=

BUILDBASE=
DISTDIR=
CACHEDIR=

# Included Micromamba version;
MICROMAMBA_VERSION_DEFAULT=1.5.1-0
MICROMAMBA_VERSION=${MICROMAMBA_VERSION_DEFAULT}

PLATTAG=win_amd64

# online or offline installer.
ONLINE=

# The default conda explicit env spec
ENV_SPEC_FILE="$(dirname "$0")"/specs/conda-spec.txt


while [[ "${1:0:1}" = "-" ]]; do
    case "${1}" in
        -b|--build-base)
            BUILDBASE=${2:?}; shift 2;;
        --build-base=*)
            BUILDBASE=${1#*=}; shift 1;;
        -d|--dist-dir)
            DISTDIR=${2:?}; shift 2;;
        --dist-dir=*)
            DISTDIR=${1#*=}; shift 1;;
        --cache-dir)
            CACHEDIR=${2:?}; shift 2;;
        --cache-dir=*)
            CACHEDIR=${1#*=}; shift 1;;
        -M|--micromamba-version)
            MICROMAMBA_VERSION=${2:?}; shift 2;;
        --micromamba-version=*)
            MICROMAMBA_VERSION=${1#*=}; shift 1;;
        --platform)
            PLATTAG=${2:?}; shift 2;;
        --platform=*)
            PLATTAG=${1#*=}; shift 1;;
        --env-spec)
            ENV_SPEC_FILE=${2:?}; shift 2;;
        --env-spec=*)
            ENV_SPEC_FILE=${1#*=}; shift 1;;
        --online)
            ONLINE=${2:?}; shift 2;;
        --online=*)
            ONLINE=${1#*=}; shift 1;;
        -h|--help)
            usage; exit 0;;
        -*)
            echo "Unknown option: $1" >&2; usage >&2; exit 1;;
     esac
done


if [[ ! ${PLATTAG:?} =~ (win32|win_amd64) ]]; then
    echo "Invalid platform tag: ${PLATTAG} (expected win32 or win_amd64)" >&2
    exit 1
fi


if [[ ! "${ONLINE}" =~ ^(yes|no)$ ]]; then
    echo "Invalid --online parameter. Expected 'yes' or 'no' got '${ONLINE}'" >&2
    exit 1
fi


if [[ ${PLATTAG} == win32 ]]; then
    CONDAPLATTAG=x86
else
    CONDAPLATTAG=x86_64
fi


BUILDBASE=${BUILDBASE:-./build}
BASEDIR="${BUILDBASE:?}"/temp.${PLATTAG}.conda-installer

CACHEDIR=${CACHEDIR:-./build/download-cache}
DISTDIR=${DISTDIR:-./dist}

if [[ -d "${BASEDIR:?}" ]]; then
    rm -r "${BASEDIR:?}"
fi

# BASEDIR/
#   conda-pkgs/
#   conda-spec.txt

mkdir -p "${CACHEDIR:?}"/conda-pkgs
mkdir -p "${BASEDIR:?}"/conda-pkgs


# Extract the n-th version component
# $ version-component 1 1.2.3a
# 1
# $ version-component 3 1.2.3a
# 3a
version-component() {
    local n=${1:?}
    local verstring=${2:?}
    declare -i comindex
    declare -a vercomp

    if [[ ! ${n} =~ ^[0-9] ]]; then
        echo "Invalid version component number ${n}" >&2;
        return 1
    fi

    IFS=. read -r -a vercomp <<< "${verstring}"
    comindex=$(( ${n} - 1 ))
    echo "${vercomp[comindex]}"
}

fetch-micromamba() {
    local version="${1:?}"
    local destdir="${2:?}"
    local url="https://github.com/mamba-org/micromamba-releases/releases/download/${version}/micromamba-win-64"
    local filename="micromamba-${version}-win-64"
    mkdir -p "${destdir:?}"
    local dest="${destdir}/${filename}"
    if [[ ! -f "${dest}" ]]; then
        local tmpname=$(mktemp "${dest}.XXXXX")
        if curl -fSL -o "${tmpname}" "${url}"; then
            mv "${tmpname}" "${dest}"
        else
            return $?
        fi
    fi
}


# extract Mayor.Minor.Micro python version string from a conda env spec file
# contents read from stdin
conda-env-spec-python-version() {
    grep -E '(^|.+/)python-([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)' |
    sed -n 's@.*python-\([^-]*\)-.*$@\1@p'
}


# $ conda-fetch-packages DESTDIR SPECFILE
#
# Given an conda env spec (as exported by `conda list --explicit`),
# download all the listed packages to DESTDIR
conda-fetch-packages() {
    local destdir="${1:?}"
    local specfile="${2:?}"
    mkdir -p "${destdir}"
    fetch-files "${destdir}" "${specfile}"
    echo "@EXPLICIT" >"${destdir}/conda-spec.txt"
    (
        cd "${destdir}"
        # list out files by creation date to (sometimes) preserve order
        # that was in specfile (should parse specfile instead)
        shopt -s nullglob
        ls -1tr *.tar.bz2 *.conda
    ) >> "${destdir}/conda-spec.txt"
}


# given a set of loose conda requirements make them concrete and export them in
# the conda-pkg-list.txt (list --export --explicit) and conda-env-spec.txt
# (conda-env-...

conda-env-spec() {   # unused
    local conda=conda
    local tempdir=.conda/envs
    (
        set -e
        local condatemp=$(mktemp -d "${tempdir:?}/env.XXXX")
        local condatemp_win=$(win-path "${condatemp:?}")
        exit-cleanup() { rm -rf "${condatemp}"; }
        trap exit-cleanup EXIT

        # create a temporary env resolving and installing all dependencies
        "${conda}"  create --yes --quiet --prefix "${condatemp_win}" "$@"
        "${conda}" list --prefix "${condatemp_win}" --export --explicit --md5 \
            > conda-pkg-list.txt
        "${conda}" list --prefix "${condatemp_win}" --export \
            > conda-env-spec.txt
        rm -rf "${condatemp}"
    )
}

md5sum_() {
    if which md5 > /dev/null 2>&1; then
        md5 -q "${1:?"Missing parameter"}"
    else
        md5sum "${1:?"Missing parameter"}" | cut -d " " -f 1
    fi
}

# fetch-files <destdir> <specfile>
#
# Read http[s] urls from specfile file and download all of them to destdir
# The format of the spec file is one that is produced by
# conda list --export --explicit --md5
fetch-files() {
    local destdir=${1:?}
    local cache="${CACHEDIR:-build/download-cache}"/conda-pkgs
    mkdir -p "${destdir}"
    grep -E "^(http(s?)|file)://.*" "${2:?}" |
    while read -r line; do
        # strip any trailing whitespace
        line=$(echo "${line}" | sed -e "s/[[:space:]]*$//")
        local hash=
        local url=
        case "${line}" in
            *#*)
                hash="${line#*#}"    # fragment md5 hash
                url="${line%%#*}"    # strip fragment
                ;;
            *)
                hash=
                url="${line}"
                ;;
        esac
        fname=${url##*/}
        # cache only if md5 hash is present in url
        if [[ ! ${hash} == "" ]]; then
            if [ ! -f "${cache}/${fname}" ] ||
                    [ ! $(md5sum_ "${cache}/${fname}") == "${hash}" ]; then
                mkdir -p "${cache}"
                (
                    tmpname=$(mktemp "${cache}/${fname}".XXXX)
                    cleanup() {
                        test -f "${tmpname}" && rm -f "${tmpname}" || true;
                    }
                    trap cleanup EXIT
                    curl -fSL -o "${tmpname}" "${url}" || exit 1
                    mv "${tmpname}" "${cache}/${fname}"
                )
            fi
            cp "${cache}/${fname}" "${destdir}"
        else
            ( cd "${destdir}"; curl -fSL -O "${url}" )
        fi
    done
}


# convert a path from posix to native win32 (if applicable).
win-path() {
    case "$(uname -s)" in
        MINGW*|CYGWIN*)
            cygpath -w "${1:?}";;
        *)
            echo "${1:?}";;
    esac
}


make-installer() {
    local scriptdir="$(dirname "$0")"
    local nsis_script="${scriptdir:?}/orange-conda.nsi"
    local outpath=${DISTDIR:?}
    local filename=${NAME:?}-${VERSION:?}-${CONDAPLATTAG}.exe
    local micromamba=micromamba.exe
    local extransisparams=()
    if [[ "${ONLINE}" == yes ]]; then
        extransisparams+=( -DONLINE )
    else
        cp "${scriptdir}/micromambainstall.bat" "${BASEDIR:?}"/install.bat
    fi
    local basedir=$(win-path "${BASEDIR:?}")
    local versionstr=${VERSION:?}
    local major=$(version-component 1 "${versionstr}")
    local minor=$(version-component 2 "${versionstr}")
    local micro=$(version-component 3 "${versionstr}")
    local pymajor=$(version-component 1 "${PYTHON_VERSION:?}")
    local pyminor=$(version-component 2 "${PYTHON_VERSION:?}")
    local pymicro=$(version-component 3 "${PYTHON_VERSION:?}")

    cat <<EOF > "${BASEDIR}"/license.txt
Acknowledgments and License Agreement
-------------------------------------

EOF
    local licenses=( LICENSE )
    for file in "${licenses[@]}"; do
        cat "${file}" >> "${BASEDIR}"/license.txt
        echo "" >> "${BASEDIR}"/license.txt
    done
    mkdir -p "${DISTDIR}"

    makensis -DOUTFILENAME="${outpath}/${filename}" \
             -DAPPNAME=Orange \
             -DVERSION=${VERSION} \
             -DVERMAJOR=${major} -DVERMINOR=${minor} -DVERMICRO=${micro} \
             -DPYMAJOR=${pymajor} -DPYMINOR=${pyminor} -DPYMICRO=${pymicro} \
             -DPYARCH=${PLATTAG} \
             -DBASEDIR="${basedir}" \
             -DINSTALL_REGISTRY_KEY=OrangeCanvas \
             -DINSTALLERICON="$(win-path "${scriptdir}")/Orange.ico" \
             -DICONDIR="orange3\icons" \
             -DLICENSE_FILE="${BASEDIR}"/license.txt \
             -DLAUNCHERMODULE="Orange.canvas" \
             "${extransisparams[@]}" \
             -NOCD \
             -V4 \
             "-X!addincludedir $(win-path "${scriptdir}")" \
             "${nsis_script:?}"
}

fetch-micromamba ${MICROMAMBA_VERSION} "${CACHEDIR:?}"/micromamba

if [[ "${ONLINE}" == yes ]]; then
    cat > "${BASEDIR}"/conda-spec.txt < "${ENV_SPEC_FILE}"
    # extract the orange version from env spec
    VERSION=$(cat < "${BASEDIR}"/conda-spec.txt |
              grep -E '(^|.+/)orange3-([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)' |
              sed -n 's@.*orange3-\([^-]*\)-.*$@\1@p')
    PYTHON_VERSION=$(conda-env-spec-python-version \
                     < "${BASEDIR:?}"/conda-spec.txt)
else
    conda-fetch-packages "${BASEDIR:?}"/conda-pkgs "${ENV_SPEC_FILE}"
    mv "${BASEDIR}/conda-pkgs/conda-spec.txt" "${BASEDIR}/"
    # extract the orange version from env spec
    VERSION=$(cat < "${BASEDIR:?}"/conda-spec.txt |
              grep -E '(^|.+/)orange3-([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)' |
              sed -n 's@.*orange3-\([^-]*\)-.*$@\1@p')
    PYTHON_VERSION=$(conda-env-spec-python-version \
                     < "${BASEDIR:?}"/conda-spec.txt)
fi

if [[ ! "${VERSION}" ]]; then
    echo "Cannot determine orange version from the environment spec" >&2
    exit 1
fi

if [[ ! "${PYTHON_VERSION}" ]]; then
    echo "Cannot determine python version from the environment spec" >&2
    exit 1;
fi

cp "${CACHEDIR:?}/micromamba/micromamba-${MICROMAMBA_VERSION}-win-64" \
   "${BASEDIR:?}/micromamba.exe"

mkdir -p "${BASEDIR:?}/icons"
cp "$(dirname "$0")"/{Orange.ico,OrangeOWS.ico} "${BASEDIR:?}/icons"
cp "$(dirname "$0")"/sitecustomize.py "${BASEDIR:?}"/
make-installer
