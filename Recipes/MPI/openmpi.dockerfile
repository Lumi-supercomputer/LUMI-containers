ARG IMAGE=docker.io/opensuse/leap:15.4
FROM ${IMAGE} AS rpms
ARG SLURM_VERSION=22.05.8

RUN zypper -n install libmariadb-devel rpm-build munge-devel pam-devel readline-devel libmunge2 python3 systemd git wget && cd / && wget https://download.schedmd.com/slurm/slurm-$SLURM_VERSION.tar.bz2         
RUN mkdir /RPMS
RUN rpmbuild -ta slurm*.tar.bz2 --define "_rpmdir /RPMS"


FROM ${IMAGE} AS deps

COPY --from=rpms /RPMS /RPMS
RUN zypper -n install libmunge2 lua53-luaposix     
RUN zypper -n install --allow-unsigned-rpm /RPMS/x86_64/*.rpm


ARG LUSTRE_VERSION=2.15.0-RC2
ARG LIBFABRIC_VERSION=v1.15.2

ENV _TOOLS="wget gzip zip git cmake libtool pkg-config"
ENV _RUNTIME="libaec0 libyaml-0-2"


# Settings for opensuse leap 15.4
ENV _SUSE_DEVEL_PACKAGES="gcc-fortran libnl3-devel libmount-devel libyaml-devel"
ENV _SUSE_PACKAGES="bzip2 libnl3-200"
ENV _SUSE_DEV_CMD=zypper\ -n\ install\ $_SUSE_DEVEL_PACKAGES\ $_TOOLS\ $_SUSE_PACKAGES\ $_RUNTIME
ENV _SUSE_CMD=zypper\-n\ install\ $_SUSE_PACKAGES\ $_RUNTIME
ENV _SUSE_SET_PYTHON=update-alternatives\ --install\ /usr/bin/python3\ python3\ /usr/bin/python3.10\ 1


ENV _INSTALL_ROOT=/opt/
ENV _SRC_ROOT=/opt/sources

RUN zypper -n remove busybox
RUN if [ -x "$(command -v zypper)" ]; then $_SUSE_DEV_CMD && zypper -n ref && zypper -n install -t pattern devel_basis && zypper clean --all ; \
    else echo "No valid package manager"; \
    fi
RUN zypper -n install --allow-unsigned-rpm /RPMS/x86_64/*.rpm
RUN ls /usr/lib64/libpmi2.so

#RUN zypper -n install --allow-unsigned-rpm /RPMS/x86_64/*.rpm
RUN mkdir -p $_INSTALL_ROOT $_SRC_ROOT

# Install Lustre
RUN cd $_SRC_ROOT/ && \
	git clone  --depth 1 --branch $LUSTRE_VERSION https://github.com/lustre/lustre-release.git && \
	cd lustre-release && \
	bash autogen.sh && ./configure --prefix=$_INSTALL_ROOT/lustre --with-o2ib=no --disable-modules && \
	export CPATH=$PWD/lnet/include/uapi/:$PWD/lustre/include/uapi/ && make -j 4 && make install 

# Install libfabric
RUN cd $_SRC_ROOT/ && \
	git clone --depth 1 --branch $LIBFABRIC_VERSION https://github.com/ofiwg/libfabric.git && \ 
	cd libfabric &&\
    	bash autogen.sh && ./configure --prefix=$_INSTALL_ROOT/libfabric && make -j 4 && make install

# Install xpmem
RUN cd $_SRC_ROOT/ && \
	git clone --depth 1 https://github.com/hpc/xpmem.git && \ 
	cd xpmem &&\
    	bash autogen.sh && ./configure --disable-kernel-module --prefix=$_INSTALL_ROOT/xpmem && make -j 4 && make install

ENV CPATH=$CPATH:$_INSTALL_ROOT/lustre/include
ENV LIBRARY_PATH=$LIBRARY_PATH:$_INSTALL_ROOT/lustre/lib
ENV PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$_INSTALL_ROOT/lustre/lib/pkgconfg

RUN zypper -n install gcc-c++
ENV CPATH=$CPATH:/usr/include/slurm
RUN cd $_SRC_ROOT && \
	git clone --depth 1 --branch v4.1.6 https://github.com/open-mpi/ompi.git &&  \
	cd ompi &&\
	./autogen.pl &&\
	./configure --with-pmi-libdir=/usr/lib64 --with-pmi=/usr/include/slurm --with-xpmem=$_INSTALL_ROOT/xpmem --with-lustre=$_INSTALL_ROOT/lustre --with-libfabric=$_INSTALL_ROOT/libfabric --prefix=$_INSTALL_ROOT/ompi && make -j4 && make install
