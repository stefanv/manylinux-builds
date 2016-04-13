#!/bin/bash
set -e

# Manylinux, openblas version, lex_ver
source /io/common_vars.sh

NAME="netCDF4"

if [ -z "$VERSIONS" ]; then
    VERSIONS="1.2.3.1"
fi

LIBNETCDF_VERSION="4.4.0"
HDF5_VERSION="1.8.16"
CYTHON_VERSION=0.23.4

if ! exists $LIBRARIES/hdf5-${HDF5_VERSION}* ; then
    echo "Please run build_hdf5s.sh first"
    exit 1
fi

# Install blas
#get_blas

# Install NetCDF

function build_netcdf() {

  ARCHIVE=netcdf-${LIBNETCDF_VERSION}.tar.gz

  if ! exists ${LIBRARIES}/netcdf-${LIBNETCDF_VERSION}.tgz ; then
    curl -LO ftp://ftp.unidata.ucar.edu/pub/netcdf/${ARCHIVE}

    BUILD_TO="/tmp/netcdf_build/usr/local"
    rm -rf ${BUILD_TO}
    mkdir -p ${BUILD_TO}

    # Install HDF5 headers
    (cd / && tar xf $LIBRARIES/hdf5-${HDF5_VERSION}.tgz)

    tar xf ${ARCHIVE}
    (cd netcdf-${LIBNETCDF_VERSION} && ./configure --prefix=${BUILD_TO} && make && make install)
    (cd netcdf-${LIBNETCDF_VERSION} && make install)
    (cd ${BUILD_TO}/../.. && \
     tar zcf ${LIBRARIES}/netcdf-${LIBNETCDF_VERSION}.tgz ./* )
  else
    echo "Using existing libnetcdf build"
  fi
}

build_netcdf

(cd / && tar xf $LIBRARIES/netcdf-$LIBNETCDF_VERSION.tgz )

# Directory to store wheels
rm_mkdir unfixed_wheels

export PATH=/usr/local/bin:${PATH}

# Compile wheels
for PYTHON in ${PYTHON_VERSIONS}; do
    PIP="$(cpython_path $PYTHON)/bin/pip"
    for VERSION in ${VERSIONS}; do
        if [ $(lex_ver $PYTHON) -ge $(lex_ver 3.5) ] ; then
            NUMPY_VERSION=1.9.1
        elif [ $(lex_ver $PYTHON) -ge $(lex_ver 3) ] ; then
            NUMPY_VERSION=1.7.2
        else
            NUMPY_VERSION=1.6.1
        fi
        echo "Building $NAME $VERSION for Python $PYTHON"
        # Put numpy into the wheelhouse to avoid rebuilding
        $PIP wheel -f $WHEELHOUSE -f $MANYLINUX_URL -w tmp \
            "numpy==$NUMPY_VERSION" "cython==$CYTHON_VERSION"
        $PIP install -f tmp "numpy==$NUMPY_VERSION" "cython==$CYTHON_VERSION"
        # Add numpy to requirements to avoid upgrading
        $PIP wheel -f tmp -w unfixed_wheels \
             "numpy==$NUMPY_VERSION" "cython==$CYTHON_VERSION" \
             "$NAME==$VERSION"
    done
done

# Bundle external shared libraries into the wheels
repair_wheelhouse unfixed_wheels $WHEELHOUSE
